require('dotenv').config();
const ethers = require('ethers');
const DeployUtils = require('./lib/DeployUtils');

let deployUtils;
const newUri = 'https://meta.cruna.cc/vault/v1/';

async function updateContractUri() {
  deployUtils = new DeployUtils(ethers);
  const chainId = await deployUtils.currentChainId();
  const contractAddress = deployUtils.getAddress(chainId, 'CrunaVault');
  const contract = await deployUtils.getContract('CrunaVault', './scripts', contractAddress, chainId);

  const tx = await contract.updateTokenURI(newUri);
  const receipt = await tx.wait();
  console.log(`Transaction was mined in block number ${receipt.blockNumber}`);
}

async function main() {
  try {
    await updateContractUri();
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

main();
