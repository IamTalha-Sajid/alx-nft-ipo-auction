// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IWhitelistProvider.sol";

/**
 * @title WhitelistProvider Contract
 * @notice Manages whitelist access for IPO auctions
 * @dev Admin-controlled whitelist with batch operations support
 */
contract WhitelistProvider is Context, AccessControl {
    /**
     * @dev Role identifier for admin access
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @dev Mapping of IPO ID to address to whitelist status
     */
    mapping(uint256 => mapping(address => bool)) public whitelistedAddresses;

    /**
     * @dev Mapping of IPO ID to list of whitelisted addresses
     */
    mapping(uint256 => address[]) public whitelistedAddressesList;

    /**
     * @dev Mapping of IPO ID to count of whitelisted addresses
     */
    mapping(uint256 => uint256) public whitelistCount;

    /**
     * @dev Emitted when an address is whitelisted for an IPO
     */
    event AddressWhitelisted(uint256 indexed ipoId, address indexed account);
    /**
     * @dev Emitted when an address is removed from whitelist for an IPO
     */
    event AddressRemovedFromWhitelist(
        uint256 indexed ipoId,
        address indexed account
    );
    /**
     * @dev Emitted when multiple addresses are whitelisted for an IPO
     */
    event BatchAddressesWhitelisted(uint256 indexed ipoId, address[] accounts);
    /**
     * @dev Emitted when multiple addresses are removed from whitelist for an IPO
     */
    event BatchAddressesRemovedFromWhitelist(
        uint256 indexed ipoId,
        address[] accounts
    );

    /**
     * @dev Restricts function access to admin role
     */
    modifier onlyAdmin() {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "WhitelistProvider: admin role required"
        );
        _;
    }

    /**
     * @dev Initializes contract and grants admin role to deployer
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Add a single address to whitelist for a specific IPO
     * @param ipoId ID of the IPO
     * @param account Address to whitelist
     */
    function addToWhitelist(uint256 ipoId, address account) external onlyAdmin {
        require(account != address(0), "WhitelistProvider: invalid address");
        require(
            !whitelistedAddresses[ipoId][account],
            "WhitelistProvider: already whitelisted"
        );

        whitelistedAddresses[ipoId][account] = true;
        whitelistedAddressesList[ipoId].push(account);
        whitelistCount[ipoId]++;

        emit AddressWhitelisted(ipoId, account);
    }

    /**
     * @notice Remove a single address from whitelist for a specific IPO
     * @param ipoId ID of the IPO
     * @param account Address to remove from whitelist
     */
    function removeFromWhitelist(
        uint256 ipoId,
        address account
    ) external onlyAdmin {
        require(account != address(0), "WhitelistProvider: invalid address");
        require(
            whitelistedAddresses[ipoId][account],
            "WhitelistProvider: not whitelisted"
        );

        whitelistedAddresses[ipoId][account] = false;
        whitelistCount[ipoId]--;

        // Remove from list (replace with last element and pop)
        address[] storage list = whitelistedAddressesList[ipoId];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == account) {
                list[i] = list[list.length - 1];
                list.pop();
                break;
            }
        }

        emit AddressRemovedFromWhitelist(ipoId, account);
    }

    /**
     * @notice Batch add addresses to whitelist for a specific IPO
     * @param ipoId ID of the IPO
     * @param accounts Array of addresses to whitelist
     */
    function batchAddToWhitelist(
        uint256 ipoId,
        address[] calldata accounts
    ) external onlyAdmin {
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (
                account != address(0) && !whitelistedAddresses[ipoId][account]
            ) {
                whitelistedAddresses[ipoId][account] = true;
                whitelistedAddressesList[ipoId].push(account);
                whitelistCount[ipoId]++;
            }
        }

        emit BatchAddressesWhitelisted(ipoId, accounts);
    }

    /**
     * @notice Batch remove addresses from whitelist for a specific IPO
     * @param ipoId ID of the IPO
     * @param accounts Array of addresses to remove from whitelist
     */
    function batchRemoveFromWhitelist(
        uint256 ipoId,
        address[] calldata accounts
    ) external onlyAdmin {
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (account != address(0) && whitelistedAddresses[ipoId][account]) {
                whitelistedAddresses[ipoId][account] = false;
                whitelistCount[ipoId]--;

                // Remove from list
                address[] storage list = whitelistedAddressesList[ipoId];
                for (uint256 j = 0; j < list.length; j++) {
                    if (list[j] == account) {
                        list[j] = list[list.length - 1];
                        list.pop();
                        break;
                    }
                }
            }
        }

        emit BatchAddressesRemovedFromWhitelist(ipoId, accounts);
    }

    /**
     * @notice Check if an address is whitelisted for a specific IPO
     * @param ipoId ID of the IPO
     * @param account Address to check
     * @return True if address is whitelisted
     */
    function isAllowed(
        uint256 ipoId,
        address account
    ) external view returns (bool) {
        return whitelistedAddresses[ipoId][account];
    }

    /**
     * @notice Get all whitelisted addresses for a specific IPO
     * @param ipoId ID of the IPO
     * @return Array of whitelisted addresses
     */
    function getWhitelistedAddresses(
        uint256 ipoId
    ) external view returns (address[] memory) {
        return whitelistedAddressesList[ipoId];
    }

    /**
     * @notice Get whitelist count for a specific IPO
     * @param ipoId ID of the IPO
     * @return Number of whitelisted addresses
     */
    function getWhitelistCount(uint256 ipoId) external view returns (uint256) {
        return whitelistCount[ipoId];
    }

    /**
     * @notice Check if an address is whitelisted for a specific IPO
     * @param ipoId ID of the IPO
     * @param account Address to check
     * @return True if address is whitelisted
     */
    function isWhitelisted(
        uint256 ipoId,
        address account
    ) external view returns (bool) {
        return whitelistedAddresses[ipoId][account];
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
