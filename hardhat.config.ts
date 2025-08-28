import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import "hardhat-contract-sizer"
require('@openzeppelin/hardhat-upgrades');
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const BASE_SEPOLIA_RPC = process.env.BASE_SEPOLIA_RPC || "";
const BASE_SEPOLIA_CHAIN_ID = process.env.BASE_SEPOLIA_CHAIN_ID || 84532;
const BASE_RPC = process.env.BASE_RPC || "";
const BASE_CHAIN_ID = process.env.BASE_CHAIN_ID || 8453;

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  networks: {
    hardhat: {},
    baseSepolia: {
      url: BASE_SEPOLIA_RPC,
      accounts: [`0x${PRIVATE_KEY}`],
      chainId: Number(BASE_SEPOLIA_CHAIN_ID),
    },
    base: {
      url: BASE_RPC,
      accounts: [`0x${PRIVATE_KEY}`],
      chainId: Number(BASE_CHAIN_ID),
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  paths: {
    deployments: "deployments",
  },
  etherscan: {
    apiKey: {
      baseSepolia: process.env.BASE_API_KEY || "",
      base: process.env.BASE_API_KEY || ""
    },
  },
  sourcify: {
    enabled: true
  },
  gasReporter: {
    enabled: true,
    currency: 'USD',
    gasPrice: 0.095,
    token: 'ETH',
    tokenPrice: '761.34',
    showMethodSig: true,
    excludeContracts: [],
    outputFile: "gas-report.txt",
    noColors: true,
  }
};

export default config;