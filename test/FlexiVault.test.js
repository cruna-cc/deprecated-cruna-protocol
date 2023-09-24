const chai = require("chai");
const {
  deployContract,
  amount,
  getTimestamp,
  signPackedData,
  deployContractUpgradeable,
  privateKeyByWallet,
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

describe("FlexiVaultManager", function () {
  const deployUtils = new DeployUtils(ethers);

  let flexiVault, flexiVaultManager;
  let registry, wallet, proxyWallet, tokenUtils, actorsManager;
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
  });

  function transferNft(nft, user) {
    return nft.connect(user)["safeTransferFrom(address,address,uint256)"];
  }

  beforeEach(async function () {
    expectCount = 0;
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

  const setProtector = async (owner, protector) => {
    const timestamp = (await getTimestamp()) - 100;
    const validFor = 3600;
    const hash = await tokenUtils.hashSetProtector(owner.address, protector.address, true, timestamp, validFor);
    const privateKey = privateKeyByWallet[protector.address];
    const signature = await signPackedData(hash, privateKey);

    await expect(actorsManager.connect(owner).setProtector(protector.address, true, timestamp, validFor, signature))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(owner.address, protector.address, true);
  };

  // it("should revert if not activated", async function () {
  //   // bob creates a vaults depositing a particle token
  //   await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
  //   // await expect(depositAssets(bob, 1, [2], [particle], [2], [1])).revertedWith("NotActivated()");
  // });
  //
  it("should create a vaults and add more assets to it", async function () {
    await flexiVault.connect(bob).activateAccount(1, false);

    // bob creates a vaults depositing a particle token
    // await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    // bob adds a stupidMonk token to his vaults
    // await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    // bob adds some bulls tokens to his vaults
    // await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));

    await depositAssets(bob, 1, [2, 2, 1], [particle, stupidMonk, bulls], [2, 1, 0], [1, 1, amount("5000")]);
    //
    // await depositERC721(bob, 1, particle, 2);
    // await depositERC721(bob, 1, stupidMonk, 1);
    // await depositERC20(bob, 1, bulls, amount("5000"));

    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);
    expect((await flexiVaultManager.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);
    expect((await flexiVaultManager.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    // bob transfers the protected to alice
    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    expect(await stupidMonk.balanceOf(fred.address)).equal(0);

    await expect(
      flexiVault.connect(alice).withdrawAssets(1, [2], [stupidMonk.address], [1], [1], [fred.address], 0, 0, 0)
    ).emit(stupidMonk, "Transfer");

    expect(await stupidMonk.balanceOf(fred.address)).equal(1);
  });

  it("should create a vaults and add generic assets in batch call", async function () {
    await flexiVault.connect(bob).activateAccount(1, false);

    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    await depositAssets(
      bob,
      1,
      [2, 2, 1, 3],
      [particle, stupidMonk, bulls, uselessWeapons],
      [2, 1, 0, 2],
      [1, 1, amount("5000"), 2]
    );
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);
    expect((await flexiVaultManager.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);
    expect((await flexiVaultManager.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));
  });

  // it("should revert if wrong token types", async function () {
  //   await flexiVault.connect(bob).activateAccount(1, false);
  //
  //   await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
  //   await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
  //   await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));
  //   await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
  //
  //   await expect(
  //     depositAssets(bob,
  //       1,
  //       [3],
  //       // particle is passed as an ERC20
  //       [particle],
  //       [2],
  //       [1]
  //     )
  //   ).to.be.reverted;
  //
  //   await expect(depositAssets(bob, 1, [5], [notAToken], [1], [1])).to.be.reverted;
  // });

  it("should create a vaults and deposit Ether ", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    await depositAssets(bob, 1, [0], [bob], [0], [0], {value: amount("1000")});
    expect((await flexiVaultManager.amountOf(1, [ethers.constants.AddressZero], [0]))[0]).equal(amount("1000"));

    const accountAddress = await flexiVaultManager.accountAddress(1);

    await expect((await ethers.provider.getBalance(accountAddress)).toString()).equal(amount("1000"));
  });

  it("should create a vaults, add assets to it, then eject and reinject again", async function () {
    expectCount = 0;
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

    await expect(flexiVault.connect(bob).injectEjectedAccount(1)).revertedWith("NotAPreviouslyEjectedAccount()");

    await expect(flexiVault.connect(bob).ejectAccount(1, 0, 0, [])).emit(flexiVaultManager, "BoundAccountEjected").withArgs(1);

    expect(await trustee.ownerOf(1)).equal(bob.address);

    await expect(flexiVault.connect(bob).ejectAccount(1, 0, 0, [])).revertedWith("AccountAlreadyEjected()");

    await trustee.connect(bob).approve(flexiVault.address, 1);

    await expect(flexiVault.connect(bob).injectEjectedAccount(1))
      .emit(flexiVaultManager, "EjectedBoundAccountReInjected")
      .withArgs(1);

    expect(await trustee.ownerOf(1)).equal(flexiVaultManager.address);

    const accountAddress = await flexiVaultManager.accountAddress(1);

    await depositAssets(bob, 1, [2], [particle], [4], [1]);

    expect(await particle.ownerOf(4)).equal(accountAddress);
  });

  it("should not allow a transfer if a protector is active", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await depositERC721(bob, 1, particle, 2);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await setProtector(bob, mark);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");
  });

  it("setting a second protector requires a protector's signature", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await depositERC721(bob, 1, particle, 2);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await setProtector(bob, mark);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");

    const timestamp = (await getTimestamp()) - 100;
    const validFor = 3600;
    const hash = await tokenUtils.hashSetProtector(bob.address, john.address, true, timestamp, validFor);
    const privateKey = privateKeyByWallet[mark.address];
    const signature = await signPackedData(hash, privateKey);

    await expect(actorsManager.connect(bob).setProtector(john.address, true, timestamp, validFor, signature))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, john.address, true);
  });

  it("should allow setting protectors and removing them and then add them again smoothly", async function () {
    console.info("TODO: Missing test");
    console.info("should allow setting protectors and removing them and then add them again smoothly");
  });

  it("should allow a transfer of the protected if a valid protector's signature is provided", async function () {
    await flexiVault.connect(bob).activateAccount(1, false);
    // expectCount = 1;

    await setProtector(bob, john);

    expect(await actorsManager.isProtectorFor(bob.address, john.address)).equal(true);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");

    const timestamp = (await getTimestamp()) - 100;
    const validFor = 3600;
    const hash = await tokenUtils.hashTransferRequest(1, alice.address, timestamp, validFor);

    // this helper function uses by default hardhat account [4], which is john, the protector
    const signature = await signPackedData(hash);

    await expect(flexiVault.protectedTransfer(1, alice.address, timestamp, validFor, signature)).revertedWith(
      "NotTheTokenOwner()"
    );

    await expect(flexiVault.connect(bob).protectedTransfer(1, fred.address, timestamp, validFor, signature)).revertedWith(
      "WrongDataOrNotSignedByProtector()"
    );

    await expect(flexiVault.connect(bob).protectedTransfer(1, alice.address, timestamp, validFor, signature))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    // transfer it back
    transferNft(flexiVault, alice)(alice.address, bob.address, 1);

    await expect(flexiVault.connect(bob).protectedTransfer(1, alice.address, timestamp, validFor, signature)).revertedWith(
      "SignatureAlreadyUsed()"
    );
  });

  it("should allow a transfer to a safe recipient level HIGH even if a protector is active", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await depositERC721(bob, 1, particle, 2);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 2, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 2);

    await setProtector(bob, mark);

    await expect(actorsManager.connect(bob).setSafeRecipient(fred.address, 2, 0, 0, 0)).revertedWith(
      "NotPermittedWhenProtectorsAreActive()"
    );

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should not allow a transfer to a safe recipient level MEDIUM if a protector is active", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await depositERC721(bob, 1, particle, 2);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 1, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 1);

    await setProtector(bob, mark);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");
  });

  it("should allow withdrawals when protectors are active if safe recipient", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await depositERC721(bob, 1, particle, 2);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 1, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 1);

    await setProtector(bob, mark);

    let account = await flexiVaultManager.accountAddress(1);

    await expect(flexiVault.connect(bob).withdrawAssets(1, [2], [particle.address], [2], [1], [alice.address], 0, 0, 0))
      .emit(particle, "Transfer")
      .withArgs(account, alice.address, 2);
  });
});
