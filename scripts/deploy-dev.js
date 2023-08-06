require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const DeployUtils = require("./lib/DeployUtils");
const {normalize} = require("../test/helpers");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);
  const chainId = await deployUtils.currentChainId();

  if (!/1337/.test(chainId)) {
    console.log("This script is only for local development");
    process.exit(1);
  }

  const [owner, h1, h2, h3, h4, h5] = await ethers.getSigners();

  let flexiVault, flexiVaultManager;
  let registry, wallet, proxyWallet, tokenUtils, factory;
  let usdc, usdt;

  tokenUtils = await deployUtils.deploy("TokenUtils");

  const _baseTokenURI = "https://meta-cruna-cc.s3.us-west-1.amazonaws.com/v1/";
  flexiVault = await deployUtils.deploy("FlexiVault", _baseTokenURI, tokenUtils.address);

  factory = await deployUtils.deployProxy("CrunaClusterFactory", flexiVault.address);
  await flexiVault.allowFactoryFor(factory.address, 0);

  registry = await deployUtils.deploy("ERC6551Registry");
  wallet = await deployUtils.deploy("ERC6551Account");
  tokenUtils = await deployUtils.deploy("TokenUtils");
  let implementation = await deployUtils.deploy("ERC6551AccountUpgradeable");
  proxyWallet = await deployUtils.deploy("ERC6551AccountProxy", implementation.address);

  flexiVaultManager = await deployUtils.deploy("FlexiVaultManager", flexiVault.address, tokenUtils.address);

  await flexiVault.initVault(flexiVaultManager.address);
  await flexiVaultManager.init(registry.address, wallet.address, proxyWallet.address);

  usdc = await deployUtils.deploy("USDCoin");
  usdt = await deployUtils.deploy("TetherUSD");
  bulls = await deployUtils.deploy("Bulls");
  fatBelly = await deployUtils.deploy("FatBelly");
  particle = await deployUtils.deploy("Particle", "https://api.particle.com/");
  stupidMonk = await deployUtils.deploy("StupidMonk", "https://api.stupidmonk.com/");
  uselessWeapons = await deployUtils.deploy("UselessWeapons", "https://api.uselessweapons.com/");

  let p = 1;
  let s = 1;
  for (let i = 0; i < 3; i++) {
    let w = (i > 1 ? h1 : i ? h2 : h3).address;
    await deployUtils.Tx(usdc.mint(w, normalize("1000")));
    await deployUtils.Tx(usdt.mint(w, normalize("1000", 6)));
    await deployUtils.Tx(bulls.mint(w, normalize("90000")));
    await deployUtils.Tx(fatBelly.mint(w, normalize("10000000")));
    await uselessWeapons.mintBatch(w, [i + 1, i + 2], [5, 12], "0x00");
    for (let k = 0; k < 10; k++) {
      await flexiVault.safeMint(0, w);
    }
    for (let k = 0; k < 5; k++) {
      await deployUtils.Tx(particle.safeMint(w, p++));
      await deployUtils.Tx(stupidMonk.safeMint(w, s++));
    }
  }

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
