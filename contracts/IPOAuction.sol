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
import "./interfaces/IScoreVerifier.sol";

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
        Reveal,
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
        Revealed,
        Canceled,
        Superseded
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
        uint64 revealEnd;
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
        uint256 amount;
        uint256 score;
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
     * @notice Interface for verifying bid scores.
     * @dev Validates bid score calculations.
     */
    IScoreVerifier public scoreVerifier;

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
     * @param revealEnd End time of reveal phase.
     */
    event IPOCreated(
        uint256 indexed ipoId,
        uint256 indexed tokenId,
        address currency,
        uint256 reserve,
        uint256 cap,
        uint64 commitStart,
        uint64 commitEnd,
        uint64 revealEnd
    );

    /********** MODIFIERS **********/
    /**
     * @notice Restricts function access to accounts with admin role.
     * @dev Reverts if caller does not have admin role.
     */
    modifier onlyAdmin() {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
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
            hasRole(PAUSER_ROLE, _msgSender()),
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
     * @param _scoreVerifier Address of the score verifier contract.
     */
    constructor(
        address _asset,
        address _whitelistProvider,
        address _scoreVerifier
    ) {
        _isValidAddress(_asset);
        _isValidAddress(_whitelistProvider);
        _isValidAddress(_scoreVerifier);

        asset = _asset;
        whitelistProvider = IWhitelistProvider(_whitelistProvider);
        scoreVerifier = IScoreVerifier(_scoreVerifier);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
    }

    /********** ADMIN FUNCTIONS **********/

    /**
     * @notice Create a new IPO auction
     * @param tokenId Token ID to auction
     * @param seller Custody wallet address
     * @param currency USDC address
     * @param commitStart UTC timestamp for commit phase start
     * @param commitEnd UTC timestamp for commit phase end
     * @param revealEnd UTC timestamp for reveal phase end
     * @param reserve Minimum acceptable bid (public)
     * @param cap Maximum allowed bid (marketValue * 1.30)
     */
    function createIPO(
        uint256 tokenId,
        address seller,
        address currency,
        uint64 commitStart,
        uint64 commitEnd,
        uint64 revealEnd,
        uint256 reserve,
        uint256 cap
    ) external onlyAdmin whenNotPaused {
        _isValidAddress(seller);
        _isValidAddress(currency);
        _isValidCurrency(currency);
        _isValidTime(commitStart, commitEnd, revealEnd);
        _isValidReserve(reserve, cap);

        uint256 ipoId = ipoCounter;
        ipoCounter++;

        ipos[ipoId] = IPO({
            tokenId: tokenId,
            seller: seller,
            currency: currency,
            commitStart: commitStart,
            commitEnd: commitEnd,
            revealEnd: revealEnd,
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
            commitEnd,
            revealEnd
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
     * @notice Updates the score verifier contract address.
     * @param _scoreVerifier Address of the new score verifier contract.
     * @dev Only callable by admin role.
     */
    function updateScoreVerifier(address _scoreVerifier) external onlyAdmin {
        _isValidAddress(_scoreVerifier);
        scoreVerifier = IScoreVerifier(_scoreVerifier);
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

    /********** INTERNAL FUNCTIONS **********/

    /**
     * @notice Check if address is valid (not zero address)
     * @param addr Address to validate
     */
    function _isValidAddress(address addr) internal pure {
        require(addr != address(0), "IPOAuction: invalid address");
    }

    /**
     * @notice Validate IPO timing parameters
     * @param commitStart Start time of commit phase
     * @param commitEnd End time of commit phase
     * @param revealEnd End time of reveal phase
     */
    function _isValidTime(
        uint64 commitStart,
        uint64 commitEnd,
        uint64 revealEnd
    ) internal view {
        require(commitStart < commitEnd, "IPOAuction: invalid commit times");
        require(commitEnd < revealEnd, "IPOAuction: invalid reveal time");
        require(
            block.timestamp < commitStart,
            "IPOAuction: commit start must be in future"
        );
    }

    /**
     * @notice Validate currency is supported
     * @param currency ERC20 token address to validate
     */
    function _isValidCurrency(address currency) internal view {
        require(
            supportedCurrencies[currency],
            "IPOAuction: currency not supported"
        );
    }

    /**
     * @notice Validate reserve and cap values
     * @param reserve Minimum acceptable bid amount
     * @param cap Maximum allowed bid amount
     */
    function _isValidReserve(uint256 reserve, uint256 cap) internal pure {
        require(reserve > 0, "IPOAuction: reserve must be positive");
        require(cap >= reserve, "IPOAuction: cap must be >= reserve");
    }

    /**
     * @notice Validate IPO ID exists
     * @param ipoId ID of the IPO to validate
     */
    function _isValidIPOId(uint256 ipoId) internal view {
        require(ipoId < ipoCounter, "IPOAuction: invalid IPO ID");
    }
}
