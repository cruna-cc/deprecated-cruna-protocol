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

  const [h1, h2, h3] =
    `0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC0x90F79bf6EB2c4f870365E785982E1f101E93b906`.split(
      ","
    );

  let crunaVault, flexiVault;
  let registry, wallet, proxyWallet, tokenUtils, factory;
  let usdc, usdt;

  // tokenUtils = await deployUtils.deploy("TokenUtils");

  const _baseTokenURI = "https://meta-cruna-cc.s3.us-west-1.amazonaws.com/v1/";
  // crunaVault = await deployUtils.deploy("CrunaVault", _baseTokenURI, tokenUtils.address);

  // await crunaVault.addCluster("Cruna Vault V1", "CRUNA", _baseTokenURI, 100000, owner.address);

  // factory = await deployUtils.deployProxy("CrunaClusterFactory", crunaVault.address);

  tokenUtils = await deployUtils.attach("TokenUtils");
  crunaVault = await deployUtils.attach("CrunaVault");

  for (let k = 0; k < 3; k++) {
    await deployUtils.Tx(
      crunaVault.safeMint(0, "0x207D075666327D8285feB943738578F75cA5A4F0"),
      "minting for 0x207D075666327D8285feB943738578F75cA5A4F0"
    );
    await deployUtils.Tx(crunaVault.safeMint(0, deployer.address), "minting for deployer");
  }

  process.exit();

  factory = await deployUtils.attach("CrunaClusterFactory");

  await deployUtils.Tx(crunaVault.allowFactoryFor(factory.address, 0), "Allowing factory");

  registry = await deployUtils.deploy("ERC6551Registry");
  wallet = await deployUtils.deploy("ERC6551Account");
  let implementation = await deployUtils.deploy("ERC6551AccountUpgradeable");
  proxyWallet = await deployUtils.deploy("ERC6551AccountProxy", implementation.address);

  flexiVault = await deployUtils.deploy("FlexiVault", crunaVault.address, tokenUtils.address);

  await crunaVault.addVault(flexiVault.address);
  await flexiVault.init(registry.address, wallet.address, proxyWallet.address);

  usdc = await deployUtils.deploy("USDCoin");
  usdt = await deployUtils.deploy("TetherUSD");
  // bulls = await deployUtils.deploy("Bulls");
  // fatBelly = await deployUtils.deploy("FatBelly");
  // particle = await deployUtils.deploy("Particle", "https://api.particle.com/");
  // stupidMonk = await deployUtils.deploy("StupidMonk", "https://api.stupidmonk.com/");
  // uselessWeapons = await deployUtils.deploy("UselessWeapons", "https://api.uselessweapons.com/");

  // let p = 1;
  // let s = 1;
  for (let i = 0; i < 3; i++) {
    let w = (i > 1 ? h3 : i ? h2 : h1).address;
    await deployUtils.Tx(usdc.mint(w, normalize("1000")));
    await deployUtils.Tx(usdt.mint(w, normalize("1000", 6)));
    //   await deployUtils.Tx(bulls.mint(w, normalize("90000")));
    //   await deployUtils.Tx(fatBelly.mint(w, normalize("10000000")));
    //   await uselessWeapons.mintBatch(w, [i + 1, i + 2], [5, 12], "0x00");
    for (let k = 0; k < 10; k++) {
      await crunaVault.safeMint(0, w);
    }
    //   for (let k = 0; k < 5; k++) {
    //     await deployUtils.Tx(particle.safeMint(w, p++));
    //     await deployUtils.Tx(stupidMonk.safeMint(w, s++));
    //   }
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
