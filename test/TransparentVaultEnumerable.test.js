const {expect, assert} = require("chai");
const {deployContractUpgradeable, deployContract, amount, assertThrowsMessage} = require("./helpers");

describe("TransparentVaultEnumerable", function () {
  let coolProjectProtected, coolProjectTransparentVault;
  // mocks
  let bulls, particle, fatBelly, stupidMonk, uselessWeapons;
  // wallets
  let e2Owner, bob, alice, fred, john, jane, mark;

  before(async function () {
    [e2Owner, bob, alice, fred, john, jane, mark] = await ethers.getSigners();
  });
  function transferNft(nft, user) {
    return nft.connect(user)["safeTransferFrom(address,address,uint256)"];
  }

  beforeEach(async function () {
    coolProjectProtected = await deployContractUpgradeable("CoolProjectProtected");

    coolProjectTransparentVault = await deployContractUpgradeable("CoolProjectTransparentVaultEnumerable", [
      coolProjectProtected.address,
    ]);

    expect(await coolProjectProtected.supportsInterface("0x8dca4bea")).to.be.true;

    await expect(coolProjectProtected.safeMint(bob.address, 1))
      .emit(coolProjectProtected, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    await coolProjectProtected.safeMint(bob.address, 2);

    await coolProjectProtected.safeMint(bob.address, 3);
    await coolProjectProtected.safeMint(bob.address, 4);
    await coolProjectProtected.safeMint(alice.address, 5);
    await coolProjectProtected.safeMint(alice.address, 6);

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

    stupidMonk = await deployContract("StupidMonk", "https://api.stupidmonk.com/");
    await stupidMonk.safeMint(bob.address, 1);
    await stupidMonk.safeMint(alice.address, 2);
    await stupidMonk.safeMint(john.address, 3);

    // erc1155
    uselessWeapons = await deployContract("UselessWeapons", "https://api.uselessweapons.com/");
    await uselessWeapons.mintBatch(bob.address, [1, 2], [5, 2], "0x00");
    await uselessWeapons.mintBatch(alice.address, [2], [2], "0x00");
    await uselessWeapons.mintBatch(john.address, [3, 4], [10, 1], "0x00");
  });

  it("should create a vault and add more assets to it", async function () {
    // bob creates a vault depositing a particle token
    await particle.connect(bob).setApprovalForAll(coolProjectTransparentVault.address, true);
    await coolProjectTransparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await coolProjectTransparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    // bob adds a stupidMonk token to his vault
    await stupidMonk.connect(bob).setApprovalForAll(coolProjectTransparentVault.address, true);
    await coolProjectTransparentVault.connect(bob).depositERC721(1, stupidMonk.address, 1);
    expect((await coolProjectTransparentVault.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);

    // bob adds some bulls tokens to his vault
    await bulls.connect(bob).approve(coolProjectTransparentVault.address, amount("10000"));
    await coolProjectTransparentVault.connect(bob).depositERC20(1, bulls.address, amount("5000"));
    expect((await coolProjectTransparentVault.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    const assets = await coolProjectTransparentVault.getAssets(1);
    expect(assets.length).equal(3);
    expect(assets[0].assetAddress).equal(particle.address);
    expect(assets[0].id).equal(2);
    expect(assets[1].assetAddress).equal(stupidMonk.address);

    assert.deepEqual(await coolProjectTransparentVault.getAssetByIndex(1, 0), assets[0]);

    // bob transfers the protected to alice
    await expect(transferNft(coolProjectProtected, bob)(bob.address, alice.address, 1))
      .emit(coolProjectProtected, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should allow a transfer if a transfer initializer is pending", async function () {
    // bob creates a vault depositing a particle token
    await particle.connect(bob).setApprovalForAll(coolProjectTransparentVault.address, true);
    await coolProjectTransparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await coolProjectTransparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(coolProjectProtected.connect(bob).setProtector(mark.address))
      .emit(coolProjectProtected, "ProtectorStarted")
      .withArgs(bob.address, mark.address, true);

    // bob transfers the protected to alice
    await expect(transferNft(coolProjectProtected, bob)(bob.address, alice.address, 1))
      .emit(coolProjectProtected, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should not allow a transfer if a transfer initializer is active", async function () {
    // bob creates a vault depositing a particle token
    await particle.connect(bob).setApprovalForAll(coolProjectTransparentVault.address, true);
    await coolProjectTransparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await coolProjectTransparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(coolProjectProtected.connect(bob).setProtector(mark.address))
      .emit(coolProjectProtected, "ProtectorStarted")
      .withArgs(bob.address, mark.address, true);

    await expect(coolProjectProtected.connect(mark).confirmProtector(bob.address))
      .emit(coolProjectProtected, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(transferNft(coolProjectProtected, bob)(bob.address, alice.address, 1)).revertedWith("TransferNotPermitted()");
  });

  it("should allow a transfer if the transfer initializer starts it", async function () {
    // bob creates a vault depositing a particle token
    await particle.connect(bob).setApprovalForAll(coolProjectTransparentVault.address, true);
    await coolProjectTransparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await coolProjectTransparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(coolProjectProtected.connect(bob).setProtector(mark.address))
      .emit(coolProjectProtected, "ProtectorStarted")
      .withArgs(bob.address, mark.address, true);

    await expect(coolProjectProtected.connect(mark).confirmProtector(bob.address))
      .emit(coolProjectProtected, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(coolProjectProtected.connect(mark).startTransfer(1, alice.address, 1000))
      .emit(coolProjectProtected, "TransferStarted")
      .withArgs(mark.address, 1, alice.address);

    await expect(coolProjectProtected.connect(bob).completeTransfer(1))
      .emit(coolProjectProtected, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    expect(await coolProjectProtected.ownerOf(1)).equal(alice.address);
    expect(await coolProjectTransparentVault.ownerOf(1)).equal(alice.address);
  });
});
