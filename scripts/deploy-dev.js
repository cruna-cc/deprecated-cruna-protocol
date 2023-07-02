require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const DeployUtils = require("./lib/DeployUtils");
const {deployContract, amount} = require("../test/helpers");
let deployUtils;

async function main() {
  deployUtils = new DeployUtils(ethers);
  const chainId = await deployUtils.currentChainId();

  if (!/1337/.test(chainId)) {
    console.log("This script is only for local development");
    process.exit(1);
  }

  const [owner, h1, h2, h3, h4, h5] = await ethers.getSigners();

  let crunaVault, flexiVault;
  let registry, wallet, proxyWallet, tokenUtils;

  tokenUtils = await deployContract("TokenUtils");

  const _baseTokenURI = "https://meta.cruna.cc/vault/v1/";
  crunaVault = await deployUtils.deploy("CrunaVault", _baseTokenURI, tokenUtils.address);

  await crunaVault.addCluster("Cruna Vault V1", "CRUNA", _baseTokenURI, 100000, owner.address);

  registry = await deployUtils.deploy("ERC6551Registry");
  wallet = await deployUtils.deploy("ERC6551Account");
  tokenUtils = await deployUtils.deploy("TokenUtils");
  let implementation = await deployUtils.deploy("ERC6551AccountUpgradeable");
  proxyWallet = await deployUtils.deploy("ERC6551AccountProxy", implementation.address);

  flexiVault = await deployUtils.deploy("FlexiVault", crunaVault.address, tokenUtils.address);

  await crunaVault.addVault(flexiVault.address);
  await flexiVault.init(registry.address, wallet.address, proxyWallet.address);

  bulls = await deployUtils.deploy("Bulls");
  fatBelly = await deployUtils.deploy("FatBelly");
  particle = await deployUtils.deploy("Particle", "https://api.particle.com/");
  stupidMonk = await deployUtils.deploy("StupidMonk", "https://api.stupidmonk.com/");
  uselessWeapons = await deployUtils.deploy("UselessWeapons", "https://api.uselessweapons.com/");

  let p = 1;
  let s = 1;
  for (let i = 0; i < 3; i++) {
    let w = (i > 1 ? h1 : i ? h2 : h3).address;
    await deployUtils.Tx(bulls.mint(w, amount("90000")));
    await deployUtils.Tx(fatBelly.mint(w, amount("10000000")));
    await uselessWeapons.mintBatch(w, [i + 1, i + 2], [5, 12], "0x00");
    for (let k = 0; k < 10; k++) {
      await crunaVault.safeMint(0, w);
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
