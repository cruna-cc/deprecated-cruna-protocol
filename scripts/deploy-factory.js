require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const DeployUtils = require("./lib/DeployUtils");
const {normalize} = require("../test/helpers");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);
  const chainId = await deployUtils.currentChainId();
  let [deployer] = await ethers.getSigners();

  // if (!/44787/.test(chainId)) {
  //   console.log("This script is only for testnet");
  //   process.exit(1);
  // }

  console.log("Deploying contracts with the account:", deployer.address, "to", network.name);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const [owner] = await ethers.getSigners();

  // const [h1, h2, h3] =
  //   `0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC0x90F79bf6EB2c4f870365E785982E1f101E93b906`.split(
  //     ","
  //   );

  let flexiVault, flexiVaultManager;
  let registry, wallet, proxyWallet, tokenUtils, factory;
  let usdc, usdt;

  const _baseTokenURI = "https://meta-cruna-cc.s3.us-west-1.amazonaws.com/v1/";

  // tokenUtils = await deployUtils.deploy("TokenUtils");
  // tokenUtils = await deployUtils.attach("TokenUtils");

  usdc = await deployUtils.attach("USDCoin");
  usdt = await deployUtils.attach("TetherUSD");
  flexiVault = await deployUtils.attach("FlexiVault");
  factory = await deployUtils.deployProxy("CrunaClusterFactory", flexiVault.address);

  console.log(`
  
All deployed. Look at export/deployed.json for the deployed addresses.
`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
