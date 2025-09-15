import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Role assignments from environment variables (required)
  if (!process.env.DEFAULT_ADMIN) {
    throw new Error("DEFAULT_ADMIN environment variable is required");
  }
  if (!process.env.PAUSER) {
    throw new Error("PAUSER environment variable is required");
  }
  if (!process.env.UPGRADER) {
    throw new Error("UPGRADER environment variable is required");
  }

  const DEFAULT_ADMIN = process.env.DEFAULT_ADMIN;
  const PAUSER = process.env.PAUSER;
  const UPGRADER = process.env.UPGRADER;

  console.log("Deploying WhitelistProvider with account:", deployer);
  console.log("Initial role assignments:");
  console.log("- DEFAULT_ADMIN:", DEFAULT_ADMIN);
  console.log("- PAUSER:", PAUSER);
  console.log("- UPGRADER:", UPGRADER);

  const WhitelistProvider = await deploy("WhitelistProvider", {
    from: deployer,
    proxy: {
      proxyContract: "UUPS",
      execute: {
        methodName: "initialize",
        args: [DEFAULT_ADMIN, PAUSER, UPGRADER],
      },
    },
    log: true,
  });

  console.log("WhitelistProvider deployed to:", WhitelistProvider.address);
  console.log("-----------------------------------------");
};

func.tags = ["WhitelistProvider"];
export default func;
