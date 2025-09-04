// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IWhitelistProvider Interface
 * @notice Interface for external whitelist verification
 * @dev Dev 2 uses this interface but does not implement it
 */
interface IWhitelistProvider {
    /**
     * @notice Check if an account is allowed to bid/receive for a specific IPO
     * @param ipoId ID of the IPO
     * @param account Address to check
     * @return True if account is allowed
     */
    function isAllowed(
        uint256 ipoId,
        address account
    ) external view returns (bool);
}
