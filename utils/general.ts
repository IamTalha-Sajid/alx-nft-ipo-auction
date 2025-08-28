import { ethers } from "hardhat";

export function getEthersProvider(networkName: string) {
    let providerURL;
    if (networkName == 'baseSepolia') {
        providerURL = process.env.BASE_SEPOLIA_RPC;
    } else if (networkName == 'base') {
        providerURL = process.env.BASE_RPC;
    } else if (networkName == 'localhost' || networkName == 'hardhat') {
        providerURL = 'http://127.0.0.1:8545/';
    } else {
        throw new Error("Invalid network provided");
    }

    if (!providerURL) {
        throw new Error("Provider URL not found");
    }

    const provider = new ethers.JsonRpcProvider(providerURL);
    return provider;
} 