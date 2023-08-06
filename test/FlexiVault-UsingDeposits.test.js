const chai = require("chai");
const {deployContract, amount, getTimestamp, signPackedData, deployContractUpgradeable} = require("./helpers");
const DeployUtils = require("../scripts/lib/DeployUtils");

let expectCount = 0;

const expect = (actual) => {
  if (expectCount > 0) {
    console.log(`> ${expectCount++}`);
  }
  return chai.expect(actual);
};

describe("FlexiVaultManager Using internal Deposits", function () {
  const deployUtils = new DeployUtils(ethers);

  let flexiVault, flexiVaultManager, actorsManager;
  let registry, wallet, proxyWallet, tokenUtils;
  // mocks
  let bulls, particle, fatBelly, stupidMonk, uselessWeapons;
  let notAToken;
  // wallets
  let owner, bob, alice, fred, john, jane, mark;

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

    actorsManager = await deployContract("ActorsManager");

    const _baseTokenURI = "https://meta.cruna.cc/vault/v1/";
    flexiVault = await deployContract("FlexiVaultMock", _baseTokenURI, tokenUtils.address, actorsManager.address);
    expect(await flexiVault.version()).to.equal("1.0.0");

    await actorsManager.init(flexiVault.address);

    registry = await deployContract("ERC6551Registry");
    wallet = await deployContract("ERC6551Account");
    let implementation = await deployContract("ERC6551AccountUpgradeable");
    proxyWallet = await deployContract("ERC6551AccountProxy", implementation.address);

    flexiVaultManager = await deployContract("FlexiVaultManager", flexiVault.address, tokenUtils.address, 100000);
    expect(await flexiVaultManager.version()).to.equal("1.0.0");

    await flexiVault.initVault(flexiVaultManager.address);
    await flexiVaultManager.init(registry.address, wallet.address, proxyWallet.address);

    await expect(flexiVault.initVault(flexiVaultManager.address)).revertedWith("VaultAlreadySet()");

    notAToken = await deployContract("NotAToken");

    await expect(flexiVault.safeMint0(bob.address))
      .emit(flexiVault, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    const uri = await flexiVault.tokenURI(1);
    expect(uri).to.equal("https://meta.cruna.cc/vault/v1/1");

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

  it("should revert if not activated", async function () {
    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await expect(flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [2], [1])).revertedWith(
      "NotActivated()"
    );
  });

  it("should create a vaults and add more assets to it", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, false);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    // bob adds a stupidMonk token to his vaults
    await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));

    await flexiVaultManager
      .connect(bob)
      .depositAssets(1, [2, 2, 1], [particle.address, stupidMonk.address, bulls.address], [2, 1, 0], [1, 1, amount("5000")]);

    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);
    expect((await flexiVaultManager.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);
    expect((await flexiVaultManager.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    // bob transfers the protected to alice
    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    expect(await stupidMonk.balanceOf(fred.address)).equal(0);

    await expect(
      flexiVaultManager.connect(alice).withdrawAssets(1, [2], [stupidMonk.address], [1], [1], [fred.address], 0, 0, 0)
    ).emit(stupidMonk, "Transfer");

    expect(await stupidMonk.balanceOf(fred.address)).equal(1);
  });

  it("should create a vaults and add generic assets in batch call", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, false);

    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    await flexiVaultManager
      .connect(bob)
      .depositAssets(
        1,
        [2, 2, 1, 3],
        [particle.address, stupidMonk.address, bulls.address, uselessWeapons.address],
        [2, 1, 0, 2],
        [1, 1, amount("5000"), 2]
      );
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);
    expect((await flexiVaultManager.amountOf(1, [stupidMonk.address], [1]))[0]).equal(1);
    expect((await flexiVaultManager.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));
  });

  it("should revert if wrong token types", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, false);

    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    await expect(
      flexiVaultManager.connect(bob).depositAssets(
        1,
        [3],
        // particle is passed as an ERC20
        [particle.address],
        [2],
        [1]
      )
    ).to.be.reverted;

    await expect(flexiVaultManager.connect(bob).depositAssets(1, [5], [notAToken.address], [1], [1])).to.be.reverted;
  });

  it("should create a vaults and deposit Ether ", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, true);

    await flexiVaultManager
      .connect(bob)
      .depositAssets(1, [0], [ethers.constants.AddressZero], [0], [0], {value: amount("1000")});
    expect((await flexiVaultManager.amountOf(1, [ethers.constants.AddressZero], [0]))[0]).equal(amount("1000"));

    const accountAddress = await flexiVaultManager.accountAddress(1);

    await expect((await ethers.provider.getBalance(accountAddress)).toString()).equal(amount("1000"));
  });

  it("should create a vaults, add assets to it, then eject and reinject again", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, true);

    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVaultManager.connect(bob).depositAssets(1, [2, 3], [particle.address, uselessWeapons.address], [2, 2], [1, 2]);
    expect((await flexiVaultManager.amountOf(1, [uselessWeapons.address], [2]))[0]).equal(2);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(fred).approve(flexiVaultManager.address, amount("10000"));
    await flexiVaultManager.connect(fred).depositAssets(1, [1], [bulls.address], [0], [amount("5000")]);
    expect((await flexiVaultManager.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    const trusteeAddress = await flexiVaultManager.trustee();
    const trustee = await deployUtils.attach("Trustee", trusteeAddress);

    expect(await trustee.ownerOf(1)).equal(flexiVaultManager.address);

    await expect(flexiVaultManager.connect(bob).reInjectEjectedAccount(1)).revertedWith("NotAPreviouslyEjectedAccount()");

    await expect(flexiVaultManager.connect(bob).ejectAccount(1, 0, 0, []))
      .emit(flexiVaultManager, "BoundAccountEjected")
      .withArgs(1);

    expect(await trustee.ownerOf(1)).equal(bob.address);

    await expect(flexiVaultManager.connect(bob).ejectAccount(1, 0, 0, [])).revertedWith("AccountAlreadyEjected()");

    await expect(flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [4], [1])).revertedWith(
      "AccountHasBeenEjected()"
    );

    await trustee.connect(bob).approve(flexiVaultManager.address, 1);

    await expect(flexiVaultManager.connect(bob).reInjectEjectedAccount(1))
      .emit(flexiVaultManager, "EjectedBoundAccountReInjected")
      .withArgs(1);

    expect(await trustee.ownerOf(1)).equal(flexiVaultManager.address);

    const accountAddress = await flexiVaultManager.accountAddress(1);

    await expect(flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [4], [1]))
      .emit(particle, "Transfer")
      .withArgs(bob.address, accountAddress, 4);

    expect(await particle.ownerOf(4)).equal(accountAddress);
  });

  it("should allow a transfer if a transfer initializer is pending", async function () {
    // expectCount = 1;
    await flexiVaultManager.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).proposeProtector(mark.address))
      .emit(actorsManager, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    // bob transfers the protected to alice
    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    await expect(transferNft(flexiVault, alice)(alice.address, bob.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(alice.address, bob.address, 1);

    await expect(actorsManager.connect(mark).acceptProposal(bob.address, true))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");

    await expect(actorsManager.connect(bob).proposeProtector(mark.address)).revertedWith("ProtectorAlreadySetByYou()");
  });

  it("should dot allow a transfer if protectors resigns successfully", async function () {
    // expectCount = 1;
    await flexiVaultManager.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).proposeProtector(mark.address))
      .emit(actorsManager, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    // like not accepting
    await expect(actorsManager.connect(mark).resignAsProtectorFor(alice.address)).revertedWith("NotAProtector()");

    await expect(actorsManager.connect(bob).proposeProtector(mark.address)).revertedWith("ProtectorAlreadySet()");

    // explicitly not acceptingbin/

    await expect(actorsManager.connect(mark).acceptProposal(bob.address, false))
      .to.emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, false);

    await expect(actorsManager.connect(mark).resignAsProtectorFor(alice.address)).revertedWith("NotAProtector()");

    // 7
    await expect(actorsManager.connect(mark).acceptProposal(bob.address, false)).revertedWith("PendingProtectorNotFound()");

    await expect(actorsManager.connect(mark).resignAsProtectorFor(alice.address)).revertedWith("NotAProtector()");

    await expect(actorsManager.connect(mark).resignAsProtectorFor(mark.address)).revertedWith("NotAProtector()");

    await expect(actorsManager.connect(mark).resignAsProtectorFor(alice.address)).revertedWith("NotAProtector()");

    await expect(actorsManager.connect(bob).proposeProtector(mark.address))
      .emit(actorsManager, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    await expect(actorsManager.connect(mark).acceptProposal(bob.address, true))
      .to.emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await actorsManager.connect(mark).resignAsProtectorFor(bob.address);

    await expect(actorsManager.connect(mark).resignAsProtectorFor(bob.address)).revertedWith("ResignationAlreadySubmitted()");
  });

  it("should not allow a transfer if a protector is active", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).proposeProtector(mark.address))
      .emit(actorsManager, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    await expect(actorsManager.connect(mark).acceptProposal(bob.address, true))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");
  });

  it("should allow a transfer of the protected if a valid protector's signature is provided", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, false);
    // expectCount = 1;

    await expect(actorsManager.connect(bob).proposeProtector(john.address))
      .emit(actorsManager, "ProtectorProposed")
      .withArgs(bob.address, john.address);

    await expect(actorsManager.connect(john).acceptProposal(bob.address, true))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, john.address, true);

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
    await flexiVaultManager.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);

    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 2, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 2);

    await expect(actorsManager.connect(bob).proposeProtector(mark.address))
      .emit(actorsManager, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    await expect(actorsManager.connect(mark).acceptProposal(bob.address, true))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(actorsManager.connect(bob).setSafeRecipient(fred.address, 2, 0, 0, 0)).revertedWith(
      "NotPermittedWhenProtectorsAreActive()"
    );

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should not allow a transfer to a safe recipient level MEDIUM if a protector is active", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 1, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 1);

    await expect(actorsManager.connect(bob).proposeProtector(mark.address))
      .emit(actorsManager, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    await expect(actorsManager.connect(mark).acceptProposal(bob.address, true))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");
  });

  it("should allow withdrawals when protectors are active if safe recipient", async function () {
    await flexiVaultManager.connect(bob).activateAccount(1, true);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVaultManager.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 1, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 1);

    await expect(actorsManager.connect(bob).proposeProtector(mark.address))
      .emit(actorsManager, "ProtectorProposed")
      .withArgs(bob.address, mark.address);

    await expect(actorsManager.connect(mark).acceptProposal(bob.address, true))
      .emit(actorsManager, "ProtectorUpdated")
      .withArgs(bob.address, mark.address, true);

    let account = await flexiVaultManager.accountAddress(1);

    await expect(flexiVaultManager.connect(bob).withdrawAssets(1, [2], [particle.address], [2], [1], [alice.address], 0, 0, 0))
      .emit(particle, "Transfer")
      .withArgs(account, alice.address, 2);
  });
});