const {expect} = require("chai");
const {deployContract, amount, getTimestamp, signPackedData, deployContractUpgradeable} = require("./helpers");
const DeployUtils = require("../scripts/lib/DeployUtils");

describe("FlexiVault", function () {
  const deployUtils = new DeployUtils(ethers);

  let crunaVault, flexiVault;
  let registry, wallet, proxyWallet, tokenUtils;
  // mocks
  let bulls, particle, fatBelly, stupidMonk, uselessWeapons;
  let notAToken;
  // wallets
  let owner, bob, alice, fred, john, jane, mark;

  let ETH, ERC20, ERC721, ERC1155;

  before(async function () {
    [owner, bob, alice, fred, john, jane, mark] = await ethers.getSigners();
  });

  function transferNft(nft, user) {
    return nft.connect(user)["safeTransferFrom(address,address,uint256)"];
  }

  beforeEach(async function () {
    tokenUtils = await deployContract("TokenUtils");
    const _baseTokenURI = "https://meta.cruna.cc/vault/v1/";
    crunaVault = await deployContract("CrunaVault", _baseTokenURI, tokenUtils.address);
    await crunaVault.addCluster("Cruna Vault V1", "CRUNA", _baseTokenURI, 100000, owner.address);

    registry = await deployContract("ERC6551Registry");
    wallet = await deployContract("ERC6551Account");
    let implementation = await deployContract("ERC6551AccountUpgradeable");
    proxyWallet = await deployContract("ERC6551AccountProxy", implementation.address);

    flexiVault = await deployContract("FlexiVault", crunaVault.address, tokenUtils.address);

    await crunaVault.addVault(flexiVault.address);
    await flexiVault.init(registry.address, wallet.address, proxyWallet.address);

    notAToken = await deployContract("NotAToken");

    await expect(crunaVault.safeMint(0, bob.address))
      .emit(crunaVault, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    await crunaVault.safeMint(0, bob.address);

    await crunaVault.safeMint(0, bob.address);
    await crunaVault.safeMint(0, bob.address);
    await crunaVault.safeMint(0, alice.address);
    await crunaVault.safeMint(0, alice.address);

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
    await particle.connect(bob).setApprovalForAll(flexiVault.address, true);
    await expect(flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1])).revertedWith("NotActivated()");
  });

  it("should create a vaults and add more assets to it", async function () {
    await flexiVault.connect(bob).activateAccount(1, false);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVault.address, true);

    // bob adds a stupidMonk token to his vaults
    await stupidMonk.connect(bob).setApprovalForAll(flexiVault.address, true);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(bob).approve(flexiVault.address, amount("10000"));

    await flexiVault
      .connect(bob)
      .depositAssets(1, [2, 2, 1], [particle.address, stupidMonk.address, bulls.address], [2, 1, 0], [1, 1, amount("5000")]);

    expect((await flexiVault.amountOf(1, [particle.address], [2]))[0]).equal(1);
    expect((await flexiVault.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);
    expect((await flexiVault.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    // bob transfers the protected to alice
    await expect(transferNft(crunaVault, bob)(bob.address, alice.address, 1))
      .emit(crunaVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    expect(await stupidMonk.balanceOf(fred.address)).equal(0);

    await expect(flexiVault.connect(alice).withdrawAssets(1, [2], [stupidMonk.address], [1], [1], [fred.address]))
      .emit(flexiVault, "Withdrawal")
      .emit(stupidMonk, "Transfer");

    expect(await stupidMonk.balanceOf(fred.address)).equal(1);
  });

  it("should create a vaults and add generic assets in batch call", async function () {
    await flexiVault.connect(bob).activateAccount(1, false);

    await particle.connect(bob).setApprovalForAll(flexiVault.address, true);
    await stupidMonk.connect(bob).setApprovalForAll(flexiVault.address, true);
    await bulls.connect(bob).approve(flexiVault.address, amount("10000"));
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVault.address, true);

    await flexiVault
      .connect(bob)
      .depositAssets(
        1,
        [2, 2, 1, 3],
        [particle.address, stupidMonk.address, bulls.address, uselessWeapons.address],
        [2, 1, 0, 2],
        [1, 1, amount("5000"), 2]
      );
    expect((await flexiVault.amountOf(1, [particle.address], [2]))[0]).equal(1);
    expect((await flexiVault.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);
    expect((await flexiVault.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));
  });

  it("should revert if wrong token types", async function () {
    await flexiVault.connect(bob).activateAccount(1, false);

    await particle.connect(bob).setApprovalForAll(flexiVault.address, true);
    await stupidMonk.connect(bob).setApprovalForAll(flexiVault.address, true);
    await bulls.connect(bob).approve(flexiVault.address, amount("10000"));
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVault.address, true);

    await expect(
      flexiVault.connect(bob).depositAssets(
        1,
        [3],
        // particle is passed as an ERC20
        [particle.address],
        [2],
        [1]
      )
    ).to.be.reverted;

    await expect(flexiVault.connect(bob).depositAssets(1, [5], [notAToken.address], [1], [1])).to.be.reverted;
  });

  it("should create a vaults and deposit Ether ", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    await flexiVault.connect(bob).depositAssets(1, [0], [ethers.constants.AddressZero], [0], [0], {value: amount("1000")});
    expect((await flexiVault.amountOf(1, [ethers.constants.AddressZero], [0]))[0]).equal(amount("1000"));

    const accountAddress = await flexiVault.accountAddress(1);

    await expect((await ethers.provider.getBalance(accountAddress)).toString()).equal(amount("1000"));
  });

  it("should create a vaults, add assets to it, then eject and reinject again", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    await particle.connect(bob).setApprovalForAll(flexiVault.address, true);
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVault.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2, 3], [particle.address, uselessWeapons.address], [2, 2], [1, 2]);
    expect((await flexiVault.amountOf(1, [uselessWeapons.address], [2]))[0]).equal(2);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(fred).approve(flexiVault.address, amount("10000"));
    await flexiVault.connect(fred).depositAssets(1, [1], [bulls.address], [0], [amount("5000")]);
    expect((await flexiVault.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    const trusteeAddress = await flexiVault.trustee();
    const trustee = await deployUtils.attach("TrusteeNFT", trusteeAddress);

    expect(await trustee.ownerOf(1)).equal(flexiVault.address);

    await expect(flexiVault.connect(bob).reInjectEjectedAccount(1)).revertedWith("NotAPreviouslyEjectedAccount()");

    await expect(flexiVault.connect(bob).ejectAccount(1)).emit(flexiVault, "BoundAccountEjected").withArgs(1);

    expect(await trustee.ownerOf(1)).equal(bob.address);

    await expect(flexiVault.connect(bob).ejectAccount(1)).revertedWith("AccountHasBeenEjected()");

    await expect(flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [4], [1])).revertedWith(
      "AccountHasBeenEjected()"
    );

    await trustee.connect(bob).approve(flexiVault.address, 1);

    await expect(flexiVault.connect(bob).reInjectEjectedAccount(1))
      .emit(flexiVault, "EjectedBoundAccountReInjected")
      .withArgs(1);

    expect(await trustee.ownerOf(1)).equal(flexiVault.address);

    const accountAddress = await flexiVault.accountAddress(1);

    await expect(flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [4], [1]))
      .emit(particle, "Transfer")
      .withArgs(bob.address, accountAddress, 4);

    expect(await particle.ownerOf(4)).equal(accountAddress);
  });

  it("should allow a transfer if a transfer initializer is pending", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVault.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(crunaVault.connect(bob).proposeProtector(mark.address))
      .emit(crunaVault, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    // bob transfers the protected to alice
    await expect(transferNft(crunaVault, bob)(bob.address, alice.address, 1))
      .emit(crunaVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    await expect(transferNft(crunaVault, alice)(alice.address, bob.address, 1))
      .emit(crunaVault, "Transfer")
      .withArgs(alice.address, bob.address, 1);

    await expect(crunaVault.connect(mark).acceptProposal(bob.address, false))
      .emit(crunaVault, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, false);

    await expect(transferNft(crunaVault, bob)(bob.address, alice.address, 1))
      .emit(crunaVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should not allow a transfer if a transfer initializer is active", async function () {
    await flexiVault.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVault.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVault.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(crunaVault.connect(bob).proposeProtector(mark.address))
      .emit(crunaVault, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    await expect(crunaVault.connect(mark).acceptProposal(bob.address, true))
      .emit(crunaVault, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(transferNft(crunaVault, bob)(bob.address, alice.address, 1)).revertedWith("TransferNotPermitted()");
  });

  it("should allow a transfer of the protected if a valid protector's signature is provided", async function () {
    await flexiVault.connect(bob).activateAccount(1, false);

    await expect(crunaVault.connect(bob).proposeProtector(john.address))
      .emit(crunaVault, "ProtectorProposed")
      .withArgs(bob.address, john.address);

    await expect(crunaVault.connect(john).acceptProposal(bob.address, true))
      .emit(crunaVault, "ProtectorUpdated")
      .withArgs(bob.address, john.address, true);

    await expect(transferNft(crunaVault, bob)(bob.address, alice.address, 1)).revertedWith("TransferNotPermitted()");

    const timestamp = (await getTimestamp()) - 100;
    const validFor = 3600;
    const hash = await tokenUtils.hashTransferRequest(1, alice.address, timestamp, validFor);

    // this helper function uses by default hardhat account [4], which is john, the protector
    const signature = await signPackedData(hash);

    await expect(crunaVault.protectedTransfer(1, alice.address, timestamp, validFor, signature)).revertedWith(
      "NotTheTokenOwner()"
    );

    await expect(crunaVault.connect(bob).protectedTransfer(1, fred.address, timestamp, validFor, signature)).revertedWith(
      "WrongDataOrNotSignedByProtector()"
    );

    await expect(crunaVault.connect(bob).protectedTransfer(1, alice.address, timestamp, validFor, signature))
      .emit(crunaVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    // transfer it back
    transferNft(crunaVault, alice)(alice.address, bob.address, 1);

    await expect(crunaVault.connect(bob).protectedTransfer(1, alice.address, timestamp, validFor, signature)).revertedWith(
      "SignatureAlreadyUsed()"
    );
  });
});
