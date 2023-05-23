const {expect} = require("chai");
const {deployContractUpgradeable, deployContract, amount, assertThrowsMessage} = require("./helpers");
const DeployUtils = require("../scripts/lib/DeployUtils");

describe("TransparentVault", function () {
  const deployUtils = new DeployUtils(ethers);

  let protectedNft, transparentVault;
  let registry, proxy, implementation;
  // mocks
  let bulls, particle, fatBelly, stupidMonk, uselessWeapons;
  let notAToken;
  // wallets
  let e2Owner, bob, alice, fred, john, jane, mark;

  before(async function () {
    [e2Owner, bob, alice, fred, john, jane, mark] = await ethers.getSigners();
  });

  function transferNft(nft, user) {
    return nft.connect(user)["safeTransferFrom(address,address,uint256)"];
  }

  beforeEach(async function () {
    protectedNft = await deployContract("CrunaProtected");

    registry = await deployContract("ERC6551Registry");
    implementation = await deployContract("ERC6551AccountUpgradeable");
    proxy = await deployContract("ERC6551AccountProxy", implementation.address);

    transparentVault = await deployContract("CrunaVault", protectedNft.address);

    await transparentVault.init(registry.address, proxy.address);

    notAToken = await deployContract("NotAToken");

    await expect(protectedNft.safeMint(bob.address, 1))
      .emit(protectedNft, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    await protectedNft.safeMint(bob.address, 2);

    await protectedNft.safeMint(bob.address, 3);
    await protectedNft.safeMint(bob.address, 4);
    await protectedNft.safeMint(alice.address, 5);
    await protectedNft.safeMint(alice.address, 6);

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

  it("should revert if not activated", async function () {
    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(transparentVault.address, true);
    await expect(transparentVault.connect(bob).depositERC721(1, particle.address, 2)).revertedWith("NotActivated()");
  });

  it("should create a vaults and add more assets to it", async function () {
    await transparentVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(transparentVault.address, true);
    await transparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await transparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    // bob adds a stupidMonk token to his vaults
    await stupidMonk.connect(bob).setApprovalForAll(transparentVault.address, true);
    await transparentVault.connect(bob).depositERC721(1, stupidMonk.address, 1);
    expect((await transparentVault.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(bob).approve(transparentVault.address, amount("10000"));
    await transparentVault.connect(bob).depositERC20(1, bulls.address, amount("5000"));
    expect((await transparentVault.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    // bob transfers the protected to alice
    await expect(transferNft(protectedNft, bob)(bob.address, alice.address, 1))
      .emit(protectedNft, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    expect(await stupidMonk.balanceOf(fred.address)).equal(0);

    await expect(transparentVault.connect(alice).withdrawAsset(1, stupidMonk.address, 1, 1, fred.address))
      .emit(transparentVault, "Withdrawal")
      .emit(stupidMonk, "Transfer");

    expect(await stupidMonk.balanceOf(fred.address)).equal(1);
  });

  it("should create a vaults and add generic assets in batch call", async function () {
    await transparentVault.connect(bob).activateAccount(1);

    await particle.connect(bob).setApprovalForAll(transparentVault.address, true);
    await stupidMonk.connect(bob).setApprovalForAll(transparentVault.address, true);
    await bulls.connect(bob).approve(transparentVault.address, amount("10000"));
    await uselessWeapons.connect(bob).setApprovalForAll(transparentVault.address, true);

    await transparentVault
      .connect(bob)
      .depositAssets(
        1,
        [particle.address, stupidMonk.address, bulls.address, uselessWeapons.address],
        [2, 1, 0, 2],
        [1, 1, amount("5000"), 2]
      );
    expect((await transparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);
    expect((await transparentVault.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);
    expect((await transparentVault.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    await expect(transparentVault.connect(bob).depositAssets(1, [notAToken.address], [1], [1])).revertedWith("InvalidAsset()");
  });

  it("should create a vaults and deposit Ether ", async function () {
    await transparentVault.connect(bob).activateAccount(1);

    await transparentVault.connect(bob).depositETH(1, {value: amount("1000")});
    expect((await transparentVault.amountOf(1, [ethers.constants.AddressZero], [0]))[0]).equal(amount("1000"));

    const accountAddress = await transparentVault.accountAddress(1);

    await expect((await ethers.provider.getBalance(accountAddress)).toString()).equal(amount("1000"));
  });

  it("should create a vaults, add assets to it, then eject and reinject again", async function () {
    await transparentVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(transparentVault.address, true);
    await transparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await transparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    // bob adds some UselessWeapons tokens to his vaults
    await uselessWeapons.connect(bob).setApprovalForAll(transparentVault.address, true);
    await transparentVault.connect(bob).depositERC1155(1, uselessWeapons.address, 2, 2);
    expect((await transparentVault.amountOf(1, [uselessWeapons.address], [2]))[0]).equal(2);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(fred).approve(transparentVault.address, amount("10000"));
    await transparentVault.connect(fred).depositERC20(1, bulls.address, amount("5000"));
    expect((await transparentVault.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    const ownerNFTaddress = await transparentVault.ownerNFT();
    const ownerNFT = await deployUtils.attach("OwnerNFT", ownerNFTaddress);

    expect(await ownerNFT.ownerOf(1)).equal(transparentVault.address);

    await expect(transparentVault.connect(bob).reInjectEjectedAccount(1)).revertedWith("NotAPreviouslyEjectedAccount()");

    await expect(transparentVault.connect(bob).ejectAccount(1)).emit(transparentVault, "BoundAccountEjected").withArgs(1);

    expect(await ownerNFT.ownerOf(1)).equal(bob.address);

    await expect(transparentVault.connect(bob).ejectAccount(1)).revertedWith("AccountHasBeenEjected()");

    await expect(transparentVault.connect(bob).depositERC721(1, particle.address, 4)).revertedWith("AccountHasBeenEjected()");

    await ownerNFT.connect(bob).approve(transparentVault.address, 1);

    await expect(transparentVault.connect(bob).reInjectEjectedAccount(1))
      .emit(transparentVault, "EjectedBoundAccountReInjected")
      .withArgs(1);

    expect(await ownerNFT.ownerOf(1)).equal(transparentVault.address);

    const accountAddress = await transparentVault.accountAddress(1);

    await expect(transparentVault.connect(bob).depositERC721(1, particle.address, 4))
      .emit(particle, "Transfer")
      .withArgs(bob.address, accountAddress, 4);

    expect(await particle.ownerOf(4)).equal(accountAddress);
  });

  it("should allow a transfer if a transfer initializer is pending", async function () {
    await transparentVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(transparentVault.address, true);
    await transparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await transparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(protectedNft.connect(bob).proposeProtector(mark.address))
      .emit(protectedNft, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    // bob transfers the protected to alice
    await expect(transferNft(protectedNft, bob)(bob.address, alice.address, 1))
      .emit(protectedNft, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    await expect(transferNft(protectedNft, alice)(alice.address, bob.address, 1))
      .emit(protectedNft, "Transfer")
      .withArgs(alice.address, bob.address, 1);

    await expect(protectedNft.connect(mark).acceptProposal(bob.address, false))
      .emit(protectedNft, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, false);

    await expect(transferNft(protectedNft, bob)(bob.address, alice.address, 1))
      .emit(protectedNft, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should not allow a transfer if a transfer initializer is active", async function () {
    await transparentVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(transparentVault.address, true);
    await transparentVault.connect(bob).depositERC721(1, particle.address, 2);
    expect((await transparentVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(protectedNft.connect(bob).proposeProtector(mark.address))
      .emit(protectedNft, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    await expect(protectedNft.connect(mark).acceptProposal(bob.address, true))
      .emit(protectedNft, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(transferNft(protectedNft, bob)(bob.address, alice.address, 1)).revertedWith("TransferNotPermitted()");
  });
});
