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

  let crunaVault, flexiVault;
  let registry, wallet, proxyWallet, tokenUtils, factory;
  let usdc, usdt;

  tokenUtils = await deployUtils.attach("TokenUtils");
  usdc = await deployUtils.attach("USDCoin");
  usdt = await deployUtils.attach("TetherUSD");
  crunaVault = await deployUtils.attach("CrunaVault");
  factory = await deployUtils.attach("CrunaClusterFactory");
  registry = await deployUtils.attach("ERC6551Registry");
  wallet = await deployUtils.attach("ERC6551Account");
  let implementation = await deployUtils.attach("ERC6551AccountUpgradeable");
  proxyWallet = await deployUtils.attach("ERC6551AccountProxy");
  flexiVault = await deployUtils.attach("FlexiVault");

  const [h1, h2, h3] = [
    "0x888De0501cDBd7f88654Eb22f9517a6c93bf014B",
    "0x4Af1958a7292eE5CeD5E71070E6e14dcEacE1349",
    "0x34923658675B99B2DB634cB2BC0cA8d25EdEC743",
  ];

  for (let i = 0; i < 3; i++) {
    let address = i === 0 ? h1 : i === 1 ? h2 : h3;
    for (let k = 0; k < 3; k++) {
      await deployUtils.Tx(crunaVault.safeMint(0, address), "minting for " + address);
    }

    // await deployUtils.Tx(usdc.mint(address, normalize("1000")));
    // await deployUtils.Tx(usdt.mint(address, normalize("1000", 6)));
    await deployUtils.Tx(crunaVault.safeMint(0, address), "minting for " + address);
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
