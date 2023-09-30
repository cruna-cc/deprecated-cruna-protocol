const chai = require("chai");
const {
  deployContract,
  amount,
  getTimestamp,
  signPackedData,
  deployContractUpgradeable,
  privateKeyByWallet,
  makeSignature,
  getChainId,
} = require("./helpers");
const DeployUtils = require("../scripts/lib/DeployUtils");

let expectCount = 0;

const hre = require("hardhat");
async function getABI(contractName) {
  const artifact = await hre.artifacts.readArtifact(contractName);
  return artifact.abi;
}

const expect = (actual) => {
  if (expectCount > 0) {
    console.log(`> ${expectCount++}`);
  }
  return chai.expect(actual);
};

describe("Beneficiaries", function () {
  // TODO This is a fake test. We need a test for the beneficiaries

  const deployUtils = new DeployUtils(ethers);

  let flexiVault, flexiVaultManager;
  let registry, wallet, proxyWallet, actorsManager;
  let guardian, signatureValidator;
  // mocks
  let bulls, particle, fatBelly, stupidMonk, uselessWeapons;
  let notAToken;
  // wallets
  let owner, bob, alice, fred, john, jane, mark;
  let timestamp;
  let validFor;
  let hash;
  let privateKey;
  let signature;

  const TokenType = {
    ETH: 0,
    ERC20: 1,
    ERC721: 2,
    ERC1155: 3,
  };

  async function depositETH(signer, owningTokenId, params = {}) {
    const accountAddress = await flexiVaultManager.accountAddress(owningTokenId);
    try {
      await signer.sendTransaction({
        to: accountAddress,
        value: params.value,
      });
    } catch (e) {
      // console.log(e)
    }
  }

  async function depositERC20(signer, owningTokenId, asset, amount) {
    const accountAddress = await flexiVaultManager.accountAddress(owningTokenId);
    const assetContract = new ethers.Contract(asset.address, await getABI("ERC20"), ethers.provider);
    const balance = await assetContract.balanceOf(signer.address);
    await assetContract.connect(signer).transfer(accountAddress, amount, {gasLimit: 1000000});
  }

  async function depositERC721(signer, owningTokenId, asset, id) {
    const accountAddress = await flexiVaultManager.accountAddress(owningTokenId);
    const assetContract = new ethers.Contract(asset.address, await getABI("ERC721"), ethers.provider);
    await assetContract.connect(signer)["safeTransferFrom(address,address,uint256)"](signer.address, accountAddress, id);
  }

  async function depositERC1155(signer, owningTokenId, asset, id, amount) {
    const accountAddress = await flexiVaultManager.accountAddress(owningTokenId);
    const assetContract = new ethers.Contract(asset.address, await getABI("ERC1155"), ethers.provider);
    await assetContract.connect(signer).safeTransferFrom(signer.address, accountAddress, id, amount, 0, {gasLimit: 1000000});
  }

  async function depositAssets(signer, owningTokenId, tokenTypes, assets, ids, amounts, params = {}) {
    for (let i = 0; i < assets.length; i++) {
      if (tokenTypes[i] === TokenType.ETH) {
        await depositETH(signer, owningTokenId, params);
      } else if (tokenTypes[i] === TokenType.ERC20) {
        await depositERC20(signer, owningTokenId, assets[i], amounts[i]);
      } else if (tokenTypes[i] === TokenType.ERC721) {
        await depositERC721(signer, owningTokenId, assets[i], ids[i]);
      } else if (tokenTypes[i] === TokenType.ERC1155) {
        await depositERC1155(signer, owningTokenId, assets[i], ids[i], amounts[i]);
      } else {
        throw new Error("Invalid asset");
      }
    }
  }

  before(async function () {
    [owner, bob, alice, fred, john, jane, mark] = await ethers.getSigners();
    chainId = await getChainId();
  });

  function transferNft(nft, user) {
    return nft.connect(user)["safeTransferFrom(address,address,uint256)"];
  }

  beforeEach(async function () {
    expectCount = 0;

    actorsManager = await deployContract("ActorsManager");
    signatureValidator = await deployContract("SignatureValidator", "Cruna", "1");

    flexiVault = await deployContract("FlexiVaultMock", actorsManager.address, signatureValidator.address);

    expect(await flexiVault.version()).to.equal("1.0.0");

    await actorsManager.init(flexiVault.address);

    registry = await deployContract("ERC6551Registry");

    guardian = await deployContract("AccountGuardian");

    let implementation = await deployContract("FlexiAccount", guardian.address);
    proxyWallet = await deployContract("ERC6551AccountProxy", implementation.address);

    flexiVaultManager = await deployContract("FlexiVaultManager", flexiVault.address);
    expect(await flexiVaultManager.version()).to.equal("1.0.0");

    await flexiVaultManager.init(registry.address, proxyWallet.address);
    await flexiVault.initVault(flexiVaultManager.address);

    await expect(flexiVault.initVault(flexiVaultManager.address)).revertedWith("VaultManagerAlreadySet()");

    notAToken = await deployContract("NotAToken");

    await expect(flexiVault.safeMint0(bob.address))
      .emit(flexiVault, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    const uri = await flexiVault.tokenURI(1);
    expect(uri).to.equal("https://meta.cruna.cc/flexy-vault/v1/1");

    await flexiVault.safeMint0(bob.address);
    await flexiVault.safeMint0(bob.address);
    await flexiVault.safeMint0(bob.address);
    await flexiVault.safeMint0(alice.address);
    await flexiVault.safeMint0(alice.address);

    // erc20
    bulls = await deployContract("Bulls");
    await bulls.mint(bob.address, amount("90000"));
    await bulls.mint(john.address, amount("60000"));
    await bulls.mint(jane.address, amount("100000"));
    await bulls.mint(alice.address, amount("100000"));
    await bulls.mint(fred.address, amount("100000"));

    fatBelly = await deployContract("FatBelly");
    await fatBelly.mint(alice.address, amount("10000000"));
    await fatBelly.mint(john.address, amount("2000000"));
    await fatBelly.mint(fred.address, amount("30000000"));

    // erc721
    particle = await deployContract("Particle", "https://api.particle.com/");
    await particle.safeMint(alice.address, 1);
    await particle.safeMint(bob.address, 2);
    await particle.safeMint(john.address, 3);
    await particle.safeMint(bob.address, 4);

    stupidMonk = await deployContract("StupidMonk", "https://api.stupidmonk.com/");
    await stupidMonk.safeMint(bob.address, 1);
    await stupidMonk.safeMint(alice.address, 2);
    await stupidMonk.safeMint(john.address, 3);
    await stupidMonk.safeMint(bob.address, 4);

    // erc1155
    uselessWeapons = await deployContract("UselessWeapons", "https://api.uselessweapons.com/");
    await uselessWeapons.mintBatch(bob.address, [1, 2], [5, 2], "0x00");
    await uselessWeapons.mintBatch(alice.address, [2], [2], "0x00");
    await uselessWeapons.mintBatch(john.address, [3, 4], [10, 1], "0x00");
  });

  const signSetProtector = async (tokenOwner, protector, timestamp, validFor = 3600, active = true, signer) => {
    const message = {
      tokenOwner: tokenOwner.address,
      protector: protector.address,
      active,
      timestamp,
      validFor,
    };

    return makeSignature(
      chainId,
      signatureValidator.address,
      privateKeyByWallet[(signer || protector).address],
      "Auth",
      [
        {name: "tokenOwner", type: "address"},
        {name: "protector", type: "address"},
        {name: "active", type: "bool"},
        {name: "timestamp", type: "uint256"},
        {name: "validFor", type: "uint256"},
      ],
      message
    );
  };

  const setProtector = async (owner, protector) => {
    const timestamp = (await getTimestamp()) - 100;
    const validFor = 3600;
    const signature = await signSetProtector(owner, protector, timestamp, validFor);

    await expect(actorsManager.connect(owner).setProtector(protector.address, true, timestamp, validFor, signature))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(owner.address, protector.address, true);
  };

  it.skip("should test beneficiaries", async function () {});
});
