const chai = require("chai");
const {deployContract, amount, getTimestamp, signPackedData, deployContractUpgradeable} = require("./helpers");
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

describe("Migration V1 to V2", function () {
  const deployUtils = new DeployUtils(ethers);

  let flexiVault, flexiVaultManager;
  let registry, wallet, proxyWallet, tokenUtils, actorsManager;
  let flexiVault2, flexiVaultManager2;
  let actorsManager2;
  // mocks
  let bulls, particle, fatBelly, stupidMonk, uselessWeapons;
  let notAToken;
  // wallets
  let owner, bob, alice, fred, john, jane, mark;

  const TokenType = {
    ETH: 0,
    ERC20: 1,
    ERC721: 2,
    ERC1155: 3,
  };

  async function depositETH(manager, signer, owningTokenId, params = {}) {
    const accountAddress = await manager.accountAddress(owningTokenId);
    try {
      await signer.sendTransaction({
        to: accountAddress,
        value: params.value,
      });
    } catch (e) {
      // console.log(e)
    }
  }

  async function depositERC20(manager, signer, owningTokenId, asset, amount) {
    const accountAddress = await manager.accountAddress(owningTokenId);
    const assetContract = new ethers.Contract(asset.address, await getABI("ERC20"), ethers.provider);
    const balance = await assetContract.balanceOf(signer.address);
    await assetContract.connect(signer).transfer(accountAddress, amount, {gasLimit: 1000000});
  }

  async function depositERC721(manager, signer, owningTokenId, asset, id) {
    const accountAddress = await manager.accountAddress(owningTokenId);
    const assetContract = new ethers.Contract(asset.address, await getABI("ERC721"), ethers.provider);
    await assetContract.connect(signer)["safeTransferFrom(address,address,uint256)"](signer.address, accountAddress, id);
  }

  async function depositERC1155(manager, signer, owningTokenId, asset, id, amount) {
    const accountAddress = await manager.accountAddress(owningTokenId);
    const assetContract = new ethers.Contract(asset.address, await getABI("ERC1155"), ethers.provider);
    await assetContract.connect(signer).safeTransferFrom(signer.address, accountAddress, id, amount, 0, {gasLimit: 1000000});
  }

  async function depositAssets(
    signer,
    owningTokenId,
    tokenTypes,
    assets,
    ids,
    amounts,
    params = {},
    manager = flexiVaultManager
  ) {
    for (let i = 0; i < assets.length; i++) {
      if (tokenTypes[i] === TokenType.ETH) {
        await depositETH(manager, signer, owningTokenId, params);
      } else if (tokenTypes[i] === TokenType.ERC20) {
        await depositERC20(manager, signer, owningTokenId, assets[i], amounts[i]);
      } else if (tokenTypes[i] === TokenType.ERC721) {
        await depositERC721(manager, signer, owningTokenId, assets[i], ids[i]);
      } else if (tokenTypes[i] === TokenType.ERC1155) {
        await depositERC1155(manager, signer, owningTokenId, assets[i], ids[i], amounts[i]);
      } else {
        throw new Error("Invalid asset");
      }
    }
  }

  before(async function () {
    [owner, bob, alice, fred, john, jane, mark] = await ethers.getSigners();
  });

  function transferNft(nft, user) {
    return nft.connect(user)["safeTransferFrom(address,address,uint256)"];
  }

  beforeEach(async function () {
    // expectCount = 1;
    tokenUtils = await deployContract("TokenUtils");
    expect(await tokenUtils.version()).to.equal("1.0.0");

    actorsManager = await deployContract("ActorsManagerV2");

    const _baseTokenURI = "https://meta.cruna.cc/flexy-vault/v1/";
    flexiVault = await deployContract("FlexiVaultMock", tokenUtils.address, actorsManager.address);
    expect(await flexiVault.version()).to.equal("1.0.0");

    await actorsManager.init(flexiVault.address);

    registry = await deployContract("ERC6551Registry");
    wallet = await deployContract("ERC6551Account");
    let implementation = await deployContract("ERC6551AccountUpgradeable");
    proxyWallet = await deployContract("ERC6551AccountProxy", implementation.address);

    flexiVaultManager = await deployContract("FlexiVaultManager", flexiVault.address, tokenUtils.address);
    expect(await flexiVaultManager.version()).to.equal("1.0.0");

    await flexiVaultManager.init(registry.address, wallet.address, proxyWallet.address);
    await flexiVault.initVault(flexiVaultManager.address);

    notAToken = await deployContract("NotAToken");

    await expect(flexiVault.safeMint0(bob.address))
      .emit(flexiVault, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    let uri = await flexiVault.tokenURI(1);
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
    await uselessWeapons.mintBatch(bob.address, [1, 2, 3, 4], [5, 2, 10, 10], "0x00");
    await uselessWeapons.mintBatch(alice.address, [2], [2], "0x00");
    await uselessWeapons.mintBatch(john.address, [3, 4], [10, 1], "0x00");

    // V2

    actorsManager2 = await deployContract("ActorsManagerV2");
    flexiVault2 = await deployContract("FlexiVaultV2", tokenUtils.address, actorsManager2.address);

    await actorsManager2.init(flexiVault2.address);

    flexiVaultManager2 = await deployContract("FlexiVaultManagerV2", flexiVault2.address, tokenUtils.address);

    await flexiVaultManager2.init(registry.address, wallet.address, proxyWallet.address);
    await flexiVaultManager2.setPreviousTrustees([flexiVault.trustee()]);
    await flexiVault2.initVault(flexiVaultManager2.address);

    await expect(flexiVault2.safeMint0(bob.address))
      .emit(flexiVault2, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 100001);

    uri = await flexiVault2.tokenURI(100001);
    expect(uri).to.equal("https://meta.cruna.cc/flexy-vault/v2/100001");

    await expect(flexiVault2.safeMint0(bob.address))
      .emit(flexiVault2, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 100002);

    await flexiVault2.safeMint0(bob.address);
    await flexiVault2.safeMint0(bob.address);
    await flexiVault2.safeMint0(alice.address);
    await flexiVault2.safeMint0(alice.address);
  });

  it("should create a vaults, add assets to it, then eject and inject in V2", async function () {
    // expectCount = 1;
    await flexiVault.connect(bob).activateAccount(1, true);

    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await depositAssets(bob, 1, [2, 3], [particle, uselessWeapons], [2, 2], [1, 2]);
    expect((await flexiVaultManager.amountOf(1, [uselessWeapons.address], [2]))[0]).equal(2);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(fred).approve(flexiVaultManager.address, amount("10000"));
    await depositAssets(fred, 1, [1], [bulls], [0], [amount("5000")]);
    expect((await flexiVaultManager.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    const trusteeAddress = await flexiVaultManager.trustee();
    const trustee = await deployUtils.attach("Trustee", trusteeAddress);

    expect(await trustee.ownerOf(1)).equal(flexiVaultManager.address);

    await expect(flexiVault.connect(bob).ejectAccount(1, 0, 0, [])).emit(flexiVaultManager, "BoundAccountEjected").withArgs(1);

    expect(await trustee.ownerOf(1)).equal(bob.address);

    await trustee.connect(bob).approve(flexiVault2.address, 1);

    await expect(flexiVault2.connect(bob).injectEjectedAccount(1)).revertedWith("ERC721: invalid token ID");

    await expect(flexiVault2.connect(bob).mintFromTrustee(1))
      .emit(flexiVault2, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    await expect(flexiVault2.connect(bob).injectEjectedAccount(1))
      .emit(flexiVaultManager2, "EjectedBoundAccountReInjected")
      .withArgs(1);

    await depositAssets(bob, 1, [2, 3], [particle, uselessWeapons], [4, 3], [1, 5], flexiVaultManager2);
    expect(await particle.ownerOf(4)).equal(await flexiVaultManager2.accountAddress(1));
  });
});
