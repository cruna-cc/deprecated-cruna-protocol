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

  const usdc = await deployUtils.attach("USDCoin");
  const usdt = await deployUtils.attach("TetherUSD");

  const [owner] = await ethers.getSigners();

  let flexiVault, flexiVaultManager;
  let registry, wallet, proxyWallet, tokenUtils, factory;

  const _baseTokenURI = "https://meta.cruna.cc/v1/";

  tokenUtils = await deployUtils.deploy("TokenUtils");
  flexiVault = await deployUtils.deploy("FlexiVault", _baseTokenURI, tokenUtils.address);
  factory = await deployUtils.deployProxy("CrunaClusterFactory", flexiVault.address);
  await deployUtils.Tx(flexiVault.allowFactoryFor(factory.address, 0), "Allowing factory");

  registry = await deployUtils.deploy("ERC6551Registry");
  wallet = await deployUtils.deploy("ERC6551Account");
  let implementation = await deployUtils.deploy("ERC6551AccountUpgradeable");
  proxyWallet = await deployUtils.deploy("ERC6551AccountProxy", implementation.address);
  flexiVaultManager = await deployUtils.deploy("FlexiVaultManager", flexiVault.address, tokenUtils.address);

  await deployUtils.Tx(flexiVault.initVault(flexiVaultManager.address), "Adding vault");
  await deployUtils.Tx(flexiVaultManager.init(registry.address, wallet.address, proxyWallet.address), "Initializing vault");

  await deployUtils.Tx(factory.setPrice(990), "PriceSet");

  await deployUtils.Tx(factory.setStableCoin(usdc.address, true), "StableCoinSet USDC");

  await deployUtils.Tx(factory.setStableCoin(usdt.address, true), "StableCoinSet USDT");

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
