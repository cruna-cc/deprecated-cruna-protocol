const {expect} = require("chai");
const {deployContractUpgradeable, deployContract, amount, assertThrowsMessage} = require("./helpers");

describe("TransparentVault", function () {
  let everdragons2Protector, everdragons2TransparentVault;
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
    everdragons2Protector = await deployContractUpgradeable("Everdragons2ProtectorMintable", [], {from: e2Owner});

    everdragons2TransparentVault = await deployContractUpgradeable("Everdragons2TransparentVault", [
      everdragons2Protector.address,
    ]);

    await everdragons2Protector.addSubordinate(everdragons2TransparentVault.address);

    expect(await everdragons2Protector.isProtector()).to.equal(true);
    expect(await everdragons2Protector.supportsInterface("0x855f1e29")).to.be.true;

    await expect(everdragons2Protector.connect(e2Owner).safeMint(bob.address, 1))
      .emit(everdragons2Protector, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1)
      .emit(everdragons2TransparentVault, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    await everdragons2Protector.connect(e2Owner).safeMint(bob.address, 2);

    await everdragons2Protector.connect(e2Owner).safeMint(bob.address, 3);
    await everdragons2Protector.connect(e2Owner).safeMint(bob.address, 4);
    await everdragons2Protector.connect(e2Owner).safeMint(alice.address, 5);
    await everdragons2Protector.connect(e2Owner).safeMint(alice.address, 6);

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

  async function configure(protectorId, allowAll_, allowWithConfirmation_, allowList_, allowListStatus_) {
    await everdragons2TransparentVault.configure(protectorId, allowAll_, allowWithConfirmation_, allowList_, allowListStatus_);
    expect(await everdragons2TransparentVault.name()).equal("Everdragons2 - Cruna Transparent Vault");
    expect(await everdragons2TransparentVault.symbol()).equal("tvNFTa");
  }

  it("should create a vault and add more assets to it", async function () {
    // bob creates a vault depositing a particle token
    await particle.connect(bob).setApprovalForAll(everdragons2TransparentVault.address, true);
    await everdragons2TransparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await everdragons2TransparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    // bob adds a stupidMonk token to his vault
    await stupidMonk.connect(bob).setApprovalForAll(everdragons2TransparentVault.address, true);
    await everdragons2TransparentVault.connect(bob).depositERC721(1, stupidMonk.address, 1);
    expect((await everdragons2TransparentVault.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);

    // bob adds some bulls tokens to his vault
    await bulls.connect(bob).approve(everdragons2TransparentVault.address, amount("10000"));
    await everdragons2TransparentVault.connect(bob).depositERC20(1, bulls.address, amount("5000"));
    expect((await everdragons2TransparentVault.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    // the protected cannot be transferred
    await expect(transferNft(everdragons2TransparentVault, bob)(bob.address, alice.address, 1)).revertedWith(
      "TransferNotAllowed()"
    );

    // bob transfers the protector to alice
    await expect(transferNft(everdragons2Protector, bob)(bob.address, alice.address, 1))
      .emit(everdragons2Protector, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should allow a transfer if a transfer initializer is pending", async function () {
    // bob creates a vault depositing a particle token
    await particle.connect(bob).setApprovalForAll(everdragons2TransparentVault.address, true);
    await everdragons2TransparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await everdragons2TransparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(everdragons2Protector.connect(bob).setInitiator(mark.address))
      .emit(everdragons2Protector, "InitiatorStarted")
      .withArgs(bob.address, mark.address, true);

    // bob transfers the protector to alice
    await expect(transferNft(everdragons2Protector, bob)(bob.address, alice.address, 1))
      .emit(everdragons2Protector, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should not allow a transfer if a transfer initializer is active", async function () {
    // bob creates a vault depositing a particle token
    await particle.connect(bob).setApprovalForAll(everdragons2TransparentVault.address, true);
    await everdragons2TransparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await everdragons2TransparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(everdragons2Protector.connect(bob).setInitiator(mark.address))
      .emit(everdragons2Protector, "InitiatorStarted")
      .withArgs(bob.address, mark.address, true);

    await expect(everdragons2Protector.connect(mark).confirmInitiator(bob.address))
      .emit(everdragons2Protector, "InitiatorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(transferNft(everdragons2Protector, bob)(bob.address, alice.address, 1)).revertedWith("TransferNotPermitted()");
  });

  it("should allow a transfer if the transfer initializer starts it", async function () {
    // bob creates a vault depositing a particle token
    await particle.connect(bob).setApprovalForAll(everdragons2TransparentVault.address, true);
    await everdragons2TransparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await everdragons2TransparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(everdragons2Protector.connect(bob).setInitiator(mark.address))
      .emit(everdragons2Protector, "InitiatorStarted")
      .withArgs(bob.address, mark.address, true);

    await expect(everdragons2Protector.connect(mark).confirmInitiator(bob.address))
      .emit(everdragons2Protector, "InitiatorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(everdragons2Protector.connect(mark).startTransfer(1, alice.address, 1000))
      .emit(everdragons2Protector, "TransferStarted")
      .withArgs(mark.address, 1, alice.address);

    await expect(everdragons2Protector.connect(bob).completeTransfer(1))
      .emit(everdragons2Protector, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    expect(await everdragons2Protector.ownerOf(1)).equal(alice.address);
    expect(await everdragons2TransparentVault.ownerOf(1)).equal(alice.address);
  });
});
