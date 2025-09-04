import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config(); // loads ALX_BACKEND_PRIVATE_KEY

// 1) EIP‑712 domain data must match the Solidity contract
const domain = {
    name: "ALX First Listings",
    version: "1",
    chainId: 84532, // Base Sepolia (or use provider.getNetwork().then(n => n.chainId))
    verifyingContract: "0x0000000000000000000000000000000000000000", // Will be set when contract is deployed
};

// 2) Types matching the Solidity structs
const types = {
    ALXScoreAttestation: [
        { name: "wallet", type: "address" },
        { name: "score", type: "uint256" },
        { name: "epochId", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" }
    ]
};

interface ALXScoreAttestation {
    wallet: string;
    score: number;
    epochId: number;
    nonce: number;
    deadline: number;
}

interface SignedALXScore {
    score: number;
    epochId: number;
    nonce: number;
    deadline: number;
    signature: string;
}

/**
 * Signs an ALXScoreAttestation for a given wallet.
 * @param walletAddress - the wallet's Ethereum address
 * @param score - the ALX Score as stored in the database
 * @param epochId - the current epoch ID
 * @param nonce - unique nonce for replay protection
 * @param deadline - timestamp when the signature expires (optional, defaults to 1 hour from now)
 * @returns a promise resolving to the signature components and score data
 */
export async function signALXScore(
    walletAddress: string,
    score: number,
    epochId: number,
    nonce: number,
    deadline?: number
): Promise<SignedALXScore> {
    const currentDeadline = deadline || Math.floor(Date.now() / 1000) + 3600; // 1 hour default
    const message: ALXScoreAttestation = {
        wallet: walletAddress,
        score,
        epochId,
        nonce,
        deadline: currentDeadline
    };

    // Create a wallet from your backend private key
    const privateKey = process.env.ALX_BACKEND_PRIVATE_KEY;
    if (!privateKey) throw new Error("Missing ALX_BACKEND_PRIVATE_KEY in env");
    const wallet = new ethers.Wallet(privateKey);

    // Sign the typed data (EIP‑712 V4)
    const signature = await wallet.signTypedData(domain, types, message);

    return {
        score,
        epochId,
        nonce,
        deadline: currentDeadline,
        signature
    };
}

/**
 * Updates the domain with the actual contract address and chain ID.
 * @param contractAddress - the deployed contract address
 * @param chainId - the chain ID (84532 for Base Sepolia, 8453 for Base Mainnet)
 */
export function updateDomain(contractAddress: string, chainId: number) {
    domain.verifyingContract = contractAddress;
    domain.chainId = chainId;
}

// Example usage
(async () => {
    const wallet = "0xC5EE6A5a3F78c05636cb3678500287A2c8AcAb12"; // wallet address
    const score = 150;           // ALX Score from your DB
    const epochId = 1;           // current epoch ID
    const nonce = 12345;         // unique nonce for replay protection

    // Generate ALX Score attestation signature
    const scoreAttestation = await signALXScore(wallet, score, epochId, nonce);
    console.log("ALX Score Attestation:", scoreAttestation);
})();
