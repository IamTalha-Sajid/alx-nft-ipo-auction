// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IScoreVerifier Interface
 * @notice Interface for external ALX Score verification
 * @dev Dev 2 uses this interface but does not implement it
 */
interface IScoreVerifier {
    /**
     * @notice Verify ALX Score attestation for a wallet
     * @param wallet Address of the wallet
     * @param score ALX Score being verified
     * @param epochId Epoch ID for the score
     * @param sig EIP-712 signature from authorized signer
     * @return True if score verification passes
     */
    function verifyScore(address wallet, uint256 score, uint256 epochId, bytes calldata sig)
        external view returns (bool);
}
