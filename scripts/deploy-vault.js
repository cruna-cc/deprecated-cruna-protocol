require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const DeployUtils = require("./lib/DeployUtils");
const {deployContract} = require("../test/helpers");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);
  const chainId = await deployUtils.currentChainId();
  const [owner] = await ethers.getSigners();

  let flexiVault, flexiVaultManager;
  let registry, wallet, proxyWallet, tokenUtils;

  const _baseTokenURI = "https://meta.cruna.cc/vault/v1/";
  flexiVault = await deployUtils.deploy("FlexiVault", _baseTokenURI);

  registry = await deployUtils.deploy("ERC6551Registry");
  wallet = await deployUtils.deploy("ERC6551Account");
  tokenUtils = await deployUtils.deploy("TokenUtils");
  let implementation = await deployUtils.deploy("ERC6551AccountUpgradeable");
  proxyWallet = await deployUtils.deploy("ERC6551AccountProxy", implementation.address);

  flexiVaultManager = await deployContract("FlexiVaultManager", flexiVault.address, tokenUtils.address, 100000);

  await flexiVault.initVault(flexiVaultManager.address);
  await flexiVaultManager.init(registry.address, wallet.address, proxyWallet.address);

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
