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
    `0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,0x90F79bf6EB2c4f870365E785982E1f101E93b906`.split(
      ","
    );

  let crunaVault, flexiVault;
  let registry, wallet, proxyWallet, tokenUtils, factory;
  let usdc, usdt;

  const _baseTokenURI = "https://meta-cruna-cc.s3.us-west-1.amazonaws.com/v1/";

  tokenUtils = await deployUtils.deploy("TokenUtils");

  usdc = await deployUtils.deploy("USDCoin");
  usdt = await deployUtils.deploy("TetherUSD");

  for (let i = 0; i < 3; i++) {
    let address = i === 0 ? h1 : i === 1 ? h2 : h3;
    await deployUtils.Tx(usdc.mint(address, normalize("1000")));
    await deployUtils.Tx(usdt.mint(address, normalize("1000", 6)));
  }

  crunaVault = await deployUtils.deploy("CrunaVault", _baseTokenURI, tokenUtils.address);
  await deployUtils.Tx(
    crunaVault.addCluster("Cruna Vault V1", "CRUNA", _baseTokenURI, 100000, owner.address),
    "Adding cluster"
  );
  factory = await deployUtils.deployProxy("CrunaClusterFactory", crunaVault.address);
  await deployUtils.Tx(crunaVault.allowFactoryFor(factory.address, 0), "Allowing factory");

  registry = await deployUtils.deploy("ERC6551Registry");
  wallet = await deployUtils.deploy("ERC6551Account");
  let implementation = await deployUtils.deploy("ERC6551AccountUpgradeable");
  proxyWallet = await deployUtils.deploy("ERC6551AccountProxy", implementation.address);
  flexiVault = await deployUtils.deploy("FlexiVault", crunaVault.address, tokenUtils.address);

  await deployUtils.Tx(crunaVault.addVault(flexiVault.address), "Adding vault");
  await deployUtils.Tx(flexiVault.init(registry.address, wallet.address, proxyWallet.address), "Initializing vault");

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
