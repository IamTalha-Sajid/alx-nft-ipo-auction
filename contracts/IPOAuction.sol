// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IWhitelistProvider.sol";
import "./lib/LibSignatureVerify.sol";

/**
 * @title IPOAuction Contract
 * @notice A smart contract for managing IPO sealed-bid auctions with commit-reveal mechanism
 * @dev Implements second-price auction with commit-reveal mechanism
 */
contract IPOAuction is Context, AccessControl, ReentrancyGuard, Pausable {
    /**
     * @dev Utility library for cryptographic signature operations.
     */
    using ECDSA for bytes32;

    /********** ROLES **********/
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /********** ENUMS **********/
    /**
     * @notice Represents the different phases of an IPO auction.
     * @dev Controls state transitions and allowed operations.
     */
    enum Phase {
        NotStarted,
        Commit,
        SettleReady,
        Settled
    }

    /**
     * @notice Represents the status of a bid in the auction.
     * @dev Tracks the lifecycle of individual bids.
     */
    enum BidStatus {
        None,
        Committed,
        Canceled
    }

    /**
     * @notice Represents the reason for a bidder default during settlement.
     * @dev Used to track why a bidder failed to complete settlement.
     */
    enum DefaultReason {
        None,
        InsufficientBalance,
        InsufficientAllowance,
        TransferFailed
    }

    /********** STRUCTS **********/
    /**
     * @notice Contains all data for a single IPO auction.
     * @dev Core auction parameters and state tracking.
     */
    struct IPO {
        uint256 tokenId;
        address seller;
        address currency;
        uint64 commitStart;
        uint64 commitEnd;
        uint256 reserve;
        uint256 cap;
        bool settled;
        uint32 commitCount;
        uint32 revealCount;
    }

    /**
     * @notice Contains metadata about a single bid.
     * @dev Tracks bid details and state.
     */
    struct BidMeta {
        bytes32 commitHash;
        uint64 commitTime;
        BidStatus status;
    }

    /********** STATE VARIABLES **********/
    /**
     * @notice Address of the asset contract being auctioned.
     * @dev Immutable contract address set at deployment.
     */
    address public immutable asset;

    /**
     * @notice Counter for tracking total number of IPO auctions.
     * @dev Increments with each new auction creation.
     */
    uint256 public ipoCounter;

    /**
     * @notice Mapping from IPO ID to IPO auction data.
     * @dev Stores all auction parameters and state.
     */
    mapping(uint256 => IPO) public ipos;

    /**
     * @notice Mapping from IPO ID to bidder to bid metadata.
     * @dev Stores all bid information for each IPO.
     */
    mapping(uint256 => mapping(address => BidMeta)) public bids;

    /**
     * @notice Mapping from IPO ID to bidder to last edit timestamp.
     * @dev Tracks edit cooldown (1 hour per IPO).
     */
    mapping(uint256 => mapping(address => uint256)) public lastEditAt;

    /**
     * @notice Mapping from IPO ID to list of bidders.
     * @dev Used for scanning bids during settlement.
     */
    mapping(uint256 => address[]) public biddersByIPO;

    /**
     * @notice Mapping of approved currencies for bidding.
     * @dev True if currency is supported, false otherwise.
     */
    mapping(address => bool) public supportedCurrencies;

    /**
     * @notice Interface for checking bidder whitelist status.
     * @dev Validates if addresses are allowed to participate.
     */
    IWhitelistProvider public whitelistProvider;

    /**
     * @notice Address of the trusted ALX backend signer.
     * @dev Used for ALX Score attestation verification.
     */
    address public trustedSigner;

    /**
     * @notice Edit cooldown period in seconds
     * @dev Used to prevent abuse of the edit function
     */
    uint256 public editCooldownPeriod;

    /********** EVENTS **********/
    /**
     * @notice Emitted when a new IPO auction is created.
     * @param ipoId Unique identifier for the IPO.
     * @param tokenId ID of the token being auctioned.
     * @param currency Address of token used for bidding.
     * @param reserve Minimum acceptable bid amount.
     * @param cap Maximum allowed bid amount.
     * @param commitStart Start time of commit phase.
     * @param commitEnd End time of commit phase.
     */
    event IPOCreated(
        uint256 indexed ipoId,
        uint256 indexed tokenId,
        address currency,
        uint256 reserve,
        uint256 cap,
        uint64 commitStart,
        uint64 commitEnd
    );

    /**
     * @notice Emitted when a bid is committed.
     * @param ipoId ID of the IPO.
     * @param bidder Address of the bidder.
     */
    event Committed(uint256 indexed ipoId, address indexed bidder);

    /**
     * @notice Emitted when a bid is edited.
     * @param ipoId ID of the IPO.
     * @param bidder Address of the bidder.
     */
    event Edited(uint256 indexed ipoId, address indexed bidder);

    /**
     * @notice Emitted when a bid is canceled.
     * @param ipoId ID of the IPO.
     * @param bidder Address of the bidder.
     */
    event Canceled(uint256 indexed ipoId, address indexed bidder);

    /**
     * @notice Emitted when settlement starts.
     * @param ipoId ID of the IPO.
     */
    event SettlementStarted(uint256 indexed ipoId);

    /**
     * @notice Emitted when a settlement attempt fails.
     * @param ipoId ID of the IPO.
     * @param bidder Address of the failing bidder.
     * @param reason Reason for failure.
     */
    event FailedAttempt(
        uint256 indexed ipoId,
        address indexed bidder,
        string reason
    );

    /**
     * @notice Emitted when a winner is determined.
     * @param ipoId ID of the IPO.
     * @param winner Address of the winning bidder.
     * @param clearingPrice Final clearing price paid.
     */
    event WinnerFinal(
        uint256 indexed ipoId,
        address indexed winner,
        uint256 clearingPrice
    );

    /**
     * @notice Emitted when auction outcome is determined.
     * @param ipoId ID of the IPO.
     * @param asset Address of the asset contract.
     * @param tokenId ID of the token.
     * @param currency Address of the currency used.
     * @param basePrice Final price (clearing price if sold, reserve if failed).
     * @param sold Whether the auction was successful.
     * @param winner Address of the winner (zero address if failed).
     * @param seller Address of the seller.
     */
    event AuctionOutcome(
        uint256 indexed ipoId,
        address indexed asset,
        uint256 indexed tokenId,
        address currency,
        uint256 basePrice,
        bool sold,
        address winner,
        address seller
    );

    /********** MODIFIERS **********/
    /**
     * @notice Restricts function access to accounts with admin role.
     * @dev Reverts if caller does not have admin role.
     */
    modifier onlyAdmin() {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "IPOAuction: admin role required"
        );
        _;
    }

    /**
     * @notice Restricts function access to accounts with pauser role.
     * @dev Reverts if caller does not have pauser role.
     */
    modifier onlyPauser() {
        require(
            hasRole(PAUSER_ROLE, msg.sender),
            "IPOAuction: pauser role required"
        );
        _;
    }

    /********** CONSTRUCTOR **********/

    /**
     * @notice Initializes the IPO auction contract.
     * @dev Sets up the core contract dependencies and grants admin roles.
     * @param _asset Address of the asset contract.
     * @param _whitelistProvider Address of the whitelist provider contract.
     * @param _trustedSigner Address of the trusted ALX backend signer.
     */
    constructor(
        address _asset,
        address _whitelistProvider,
        address _trustedSigner,
        uint256 _editCooldownPeriod
    ) {
        _isValidAddress(_asset);
        _isValidAddress(_whitelistProvider);
        _isValidAddress(_trustedSigner);
        _isValidPeriod(_editCooldownPeriod);

        asset = _asset;
        whitelistProvider = IWhitelistProvider(_whitelistProvider);
        trustedSigner = _trustedSigner;
        editCooldownPeriod = _editCooldownPeriod;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /********** ADMIN FUNCTIONS **********/

    /**
     * @notice Create a new IPO auction
     * @param tokenId Token ID to auction
     * @param seller Custody wallet address
     * @param currency USDC address
     * @param commitStart UTC timestamp for commit phase start
     * @param commitEnd UTC timestamp for commit phase end
     * @param reserve Minimum acceptable bid (public)
     * @param cap Maximum allowed bid (marketValue * 1.30)
     */
    function createIPO(
        uint256 tokenId,
        address seller,
        address currency,
        uint64 commitStart,
        uint64 commitEnd,
        uint256 reserve,
        uint256 cap
    ) external onlyAdmin whenNotPaused {
        _isValidAddress(seller);
        _isValidAddress(currency);
        _isValidCurrency(currency);
        _isValidTime(commitStart, commitEnd);
        _isValidReserve(reserve, cap);

        uint256 ipoId = ipoCounter;
        ipoCounter++;

        ipos[ipoId] = IPO({
            tokenId: tokenId,
            seller: seller,
            currency: currency,
            commitStart: commitStart,
            commitEnd: commitEnd,
            reserve: reserve,
            cap: cap,
            settled: false,
            commitCount: 0,
            revealCount: 0
        });

        emit IPOCreated(
            ipoId,
            tokenId,
            currency,
            reserve,
            cap,
            commitStart,
            commitEnd
        );
    }

    /**
     * @notice Updates the whitelist provider contract address.
     * @param _whitelistProvider Address of the new whitelist provider contract.
     * @dev Only callable by admin role.
     */
    function updateWhitelistProvider(
        address _whitelistProvider
    ) external onlyAdmin {
        _isValidAddress(_whitelistProvider);
        whitelistProvider = IWhitelistProvider(_whitelistProvider);
    }

    /**
     * @notice Updates the trusted ALX backend signer address.
     * @param _trustedSigner Address of the new trusted signer.
     * @dev Only callable by admin role.
     */
    function updateTrustedSigner(address _trustedSigner) external onlyAdmin {
        _isValidAddress(_trustedSigner);
        trustedSigner = _trustedSigner;
    }

    /**
     * @notice Sets whether a currency is supported for IPO bids.
     * @param currency Address of the ERC20 token to configure.
     * @param isSupported True to enable support, false to disable.
     * @dev Only callable by admin role.
     */
    function setSupportedCurrency(
        address currency,
        bool isSupported
    ) external onlyAdmin {
        _isValidAddress(currency);
        supportedCurrencies[currency] = isSupported;
    }

    /**
     * @notice Batch sets support status for multiple currencies.
     * @param currencies Array of ERC20 token addresses to configure.
     * @param isSupported True to enable support, false to disable for all currencies.
     * @dev Only callable by admin role.
     */
    function setBatchSupportedCurrencies(
        address[] calldata currencies,
        bool isSupported
    ) external onlyAdmin {
        for (uint256 i = 0; i < currencies.length; i++) {
            _isValidAddress(currencies[i]);
            supportedCurrencies[currencies[i]] = isSupported;
        }
    }

    /**
     * @notice Updates the edit cooldown period.
     * @param _editCooldownPeriod New edit cooldown period in seconds.
     * @dev Only callable by admin role.
     */
    function updateEditCooldownPeriod(
        uint256 _editCooldownPeriod
    ) external onlyAdmin {
        _isValidPeriod(_editCooldownPeriod);
        editCooldownPeriod = _editCooldownPeriod;
    }

    /**
     * @notice Pauses all contract operations.
     * @dev Only callable by pauser role.
     */
    function pause() external onlyPauser {
        _pause();
    }

    /**
     * @notice Unpauses contract operations.
     * @dev Only callable by pauser role.
     */
    function unpause() external onlyPauser {
        _unpause();
    }

    /********** PUBLIC FUNCTIONS **********/

    /**
     * @notice Commit a sealed bid with wallet-signal validation.
     * @param ipoId ID of the IPO to bid on.
     * @param commitHash Hash of the bid commitment (keccak256(salt, amount, bidder)).
     * @dev Bids are sealed until reveal phase. No funds are moved, only balance/allowance checked.
     */
    function commitBid(
        uint256 ipoId,
        bytes32 commitHash
    ) external whenNotPaused nonReentrant {
        _isValidIPOId(ipoId);
        _isValidPhaseToCommit(ipoId);
        _isWhitelisted(ipoId, msg.sender);
        _hasNoActiveBid(ipoId, msg.sender);

        IPO storage ipo = ipos[ipoId];
        BidMeta storage bid = bids[ipoId][msg.sender];

        bid.commitHash = commitHash;
        bid.commitTime = uint64(block.timestamp);
        bid.status = BidStatus.Committed;

        biddersByIPO[ipoId].push(msg.sender);
        ipo.commitCount++;

        emit Committed(ipoId, msg.sender);
    }

    /**
     * @notice Edit a sealed bid with wallet-signal validation.
     * @param ipoId ID of the IPO to edit bid on.
     * @param newCommitHash New hash of the bid commitment.
     * @dev Allows editing once per hour per IPO. Re-checks wallet-signal.
     */
    function editBid(
        uint256 ipoId,
        bytes32 newCommitHash
    ) external whenNotPaused nonReentrant {
        _isValidIPOId(ipoId);
        _isValidPhaseToCommit(ipoId);
        _isWhitelisted(ipoId, msg.sender);
        _isValidBidToEdit(ipoId, msg.sender);

        lastEditAt[ipoId][msg.sender] = block.timestamp;

        BidMeta storage bid = bids[ipoId][msg.sender];

        bid.commitHash = newCommitHash;
        bid.commitTime = uint64(block.timestamp);

        emit Edited(ipoId, msg.sender);
    }

    /**
     * @notice Cancel a bid before settlement.
     * @param ipoId ID of the IPO to cancel bid on.
     * @dev Cancels the bid and marks it as canceled.
     */
    function cancelBid(uint256 ipoId) external nonReentrant {
        _isValidIPOId(ipoId);
        _isValidPhaseToCommit(ipoId);
        _isWhitelisted(ipoId, msg.sender);
        _isValidBidToCancel(ipoId, msg.sender);

        BidMeta storage bid = bids[ipoId][msg.sender];

        require(
            bid.status == BidStatus.Committed,
            "IPOAuction: No active bid to cancel"
        );

        bid.status = BidStatus.Canceled;
        emit Canceled(ipoId, msg.sender);
    }

    /**
     * @notice Get the current phase of an IPO.
     * @param ipoId ID of the IPO.
     * @return Current phase of the IPO.
     */
    function getPhase(uint256 ipoId) external view returns (Phase) {
        _isValidIPOId(ipoId);
        IPO storage ipo = ipos[ipoId];

        if (ipo.settled) {
            return Phase.Settled;
        }

        if (block.timestamp < ipo.commitStart) {
            return Phase.NotStarted;
        }

        if (block.timestamp < ipo.commitEnd) {
            return Phase.Commit;
        }

        return Phase.SettleReady;
    }

    /**
     * @notice Get bid information for a specific bidder on an IPO.
     * @param ipoId ID of the IPO.
     * @param bidder Address of the bidder.
     * @return Bid metadata including escrowed amount, commit hash, commit time, amount, score, and status.
     */
    function getBid(
        uint256 ipoId,
        address bidder
    ) external view returns (BidMeta memory) {
        _isValidIPOId(ipoId);
        return bids[ipoId][bidder];
    }

    /**
     * @notice Get all bidders for a specific IPO.
     * @param ipoId ID of the IPO.
     * @return Array of bidder addresses.
     */
    function getBidders(
        uint256 ipoId
    ) external view returns (address[] memory) {
        _isValidIPOId(ipoId);
        return biddersByIPO[ipoId];
    }

    /********** INTERNAL FUNCTIONS **********/

    /**
     * @notice Check if address is valid (not zero address)
     * @param addr Address to validate
     */
    function _isValidAddress(address addr) internal pure {
        require(addr != address(0), "IPOAuction: Invalid address");
    }

    /**
     * @notice Validate IPO timing parameters
     * @param commitStart Start time of commit phase
     * @param commitEnd End time of commit phase
     */
    function _isValidTime(uint64 commitStart, uint64 commitEnd) internal view {
        require(commitStart < commitEnd, "IPOAuction: Invalid commit times");
        require(
            block.timestamp < commitStart,
            "IPOAuction: Commit start must be in future"
        );
    }

    /**
     * @notice Validate currency is supported
     * @param currency ERC20 token address to validate
     */
    function _isValidCurrency(address currency) internal view {
        require(
            supportedCurrencies[currency],
            "IPOAuction: Currency not supported"
        );
    }

    /**
     * @notice Validate reserve and cap values
     * @param reserve Minimum acceptable bid amount
     * @param cap Maximum allowed bid amount
     */
    function _isValidReserve(uint256 reserve, uint256 cap) internal pure {
        require(reserve > 0, "IPOAuction: Reserve must be positive");
        require(cap >= reserve, "IPOAuction: Cap must be >= reserve");
    }

    /**
     * @notice Validate IPO ID exists
     * @param ipoId ID of the IPO to validate
     */
    function _isValidIPOId(uint256 ipoId) internal view {
        require(ipoId < ipoCounter, "IPOAuction: Invalid IPO ID");
    }

    /**
     * @notice Validate that the current time is within the commit phase
     * @param ipoId ID of the IPO to validate
     */
    function _isValidPhaseToCommit(uint256 ipoId) internal view {
        IPO storage ipo = ipos[ipoId];
        require(
            block.timestamp >= ipo.commitStart &&
                block.timestamp < ipo.commitEnd,
            "IPOAuction: Not in commit phase"
        );
    }

    /**
     * @notice Validate that the caller is whitelisted for the IPO
     * @param ipoId ID of the IPO to validate
     * @param bidder Address of the bidder to check
     */
    function _isWhitelisted(uint256 ipoId, address bidder) internal view {
        require(
            whitelistProvider.isAllowed(ipoId, bidder),
            "IPOAuction: Not whitelisted"
        );
    }

    /**
     * @notice Validate that the bidder doesn't have an active bid
     * @param ipoId ID of the IPO to validate
     * @param bidder Address of the bidder to check
     */
    function _hasNoActiveBid(uint256 ipoId, address bidder) internal view {
        BidMeta storage bid = bids[ipoId][bidder];
        require(
            bid.status == BidStatus.None || bid.status == BidStatus.Canceled,
            "IPOAuction: Active bid exists"
        );
    }

    /**
     * @notice Validate that the bidder has an active bid to edit
     * @param ipoId ID of the IPO to validate
     * @param bidder Address of the bidder to check
     */
    function _isValidBidToEdit(uint256 ipoId, address bidder) internal view {
        BidMeta storage bid = bids[ipoId][bidder];
        require(
            bid.status == BidStatus.Committed,
            "IPOAuction: No active bid to edit"
        );

        uint256 lastEdit = lastEditAt[ipoId][msg.sender];
        require(
            block.timestamp >= lastEdit + editCooldownPeriod,
            "IPOAuction: Edit cooldown"
        );
    }

    /**
     * @notice Validate that the bidder has an active bid to cancel
     * @param ipoId ID of the IPO to validate
     * @param bidder Address of the bidder to check
     */
    function _isValidBidToCancel(uint256 ipoId, address bidder) internal view {
        BidMeta storage bid = bids[ipoId][bidder];
        require(
            bid.status == BidStatus.Committed,
            "IPOAuction: No active bid to cancel"
        );
    }

    /**
     * @notice Validate that the period is valid
     * @param period Period to validate
     */
    function _isValidPeriod(uint256 period) internal pure {
        require(period > 0, "IPOAuction: period must be positive");
    }
}
