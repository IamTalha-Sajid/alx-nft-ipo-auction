import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Get deployed WhitelistProvider address
  const whitelistProvider = await deployments.get("WhitelistProvider");

  // Configuration parameters from environment variables (required)
  if (!process.env.ASSET_ADDRESS) {
    throw new Error("ASSET_ADDRESS environment variable is required");
  }
  if (!process.env.TRUSTED_SIGNER) {
    throw new Error("TRUSTED_SIGNER environment variable is required");
  }
  if (!process.env.EDIT_COOLDOWN_PERIOD) {
    throw new Error("EDIT_COOLDOWN_PERIOD environment variable is required");
  }

  // Role assignments from environment variables (required)
  if (!process.env.DEFAULT_ADMIN) {
    throw new Error("DEFAULT_ADMIN environment variable is required");
  }
  if (!process.env.ADMIN) {
    throw new Error("ADMIN environment variable is required");
  }
  if (!process.env.PAUSER) {
    throw new Error("PAUSER environment variable is required");
  }
  if (!process.env.RELAYER) {
    throw new Error("RELAYER environment variable is required");
  }

  const ASSET_ADDRESS = process.env.ASSET_ADDRESS;
  const TRUSTED_SIGNER = process.env.TRUSTED_SIGNER;
  const EDIT_COOLDOWN_PERIOD = parseInt(process.env.EDIT_COOLDOWN_PERIOD);
  const DEFAULT_ADMIN = process.env.DEFAULT_ADMIN;
  const ADMIN = process.env.ADMIN;
  const PAUSER = process.env.PAUSER;
  const RELAYER = process.env.RELAYER;

  console.log("Deploying IPOAuction with account:", deployer);
  console.log("Configuration:");
  console.log("- Asset Address:", ASSET_ADDRESS);
  console.log("- WhitelistProvider:", whitelistProvider.address);
  console.log("- Trusted Signer:", TRUSTED_SIGNER);
  console.log("- Edit Cooldown Period:", EDIT_COOLDOWN_PERIOD, "seconds");
  console.log("Initial role assignments:");
  console.log("- DEFAULT_ADMIN:", DEFAULT_ADMIN);
  console.log("- ADMIN:", ADMIN);
  console.log("- PAUSER:", PAUSER);
  console.log("- RELAYER:", RELAYER);

  const IPOAuction = await deploy("IPOAuction", {
    from: deployer,
    proxy: {
      proxyContract: "UUPS",
      execute: {
        methodName: "initialize",
        args: [
          ASSET_ADDRESS,
          whitelistProvider.address,
          TRUSTED_SIGNER,
          EDIT_COOLDOWN_PERIOD,
          DEFAULT_ADMIN,
          ADMIN,
          PAUSER,
          RELAYER
        ],
      },
    },
    log: true,
  });

  console.log("IPOAuction deployed to:", IPOAuction.address);
  console.log("-----------------------------------------");
};

func.tags = ["IPOAuction"];
func.dependencies = ["WhitelistProvider"];
export default func;
