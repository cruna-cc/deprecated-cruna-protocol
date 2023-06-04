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

  let crunaVault, flexiVault;
  let registry, wallet, proxyWallet, tokenUtils;

  const _baseTokenURI = "https://meta.cruna.cc/vault/v1/";
  crunaVault = await deployUtils.deploy("CrunaVault", _baseTokenURI);
  await crunaVault.addCluster("Cruna Vault V1", "CRUNA", _baseTokenURI, 100000, owner.address);

  registry = await deployUtils.deploy("ERC6551Registry");
  wallet = await deployUtils.deploy("ERC6551Account");
  tokenUtils = await deployUtils.deploy("TokenUtils");
  let implementation = await deployUtils.deploy("ERC6551AccountUpgradeable");
  proxyWallet = await deployUtils.deploy("ERC6551AccountProxy", implementation.address);

  flexiVault = await deployContract("FlexiVault", crunaVault.address, tokenUtils.address);

  await crunaVault.addVault(flexiVault.address);
  await flexiVault.init(registry.address, wallet.address, proxyWallet.address);

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
