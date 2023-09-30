const chai = require("chai");
const {
  deployContract,
  amount,
  getTimestamp,
  signPackedData,
  privateKeyByWallet,
  makeSignature,
  getChainId,
  getTypesFromSelector,
} = require("./helpers");
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
  let registry, wallet, proxyWallet;
  // mocks
  let bulls, particle, fatBelly, stupidMonk, uselessWeapons;
  let notAToken;
  let guardian, signatureValidator;
  // wallets
  let owner, bob, alice, fred, john, jane, mark;
  let timestamp, validFor, signature, chainId;

  before(async function () {
    chainId = await getChainId();
    [owner, bob, alice, fred, john, jane, mark] = await ethers.getSigners();
  });

  function transferNft(nft, user) {
    return nft.connect(user)["safeTransferFrom(address,address,uint256)"];
  }

  beforeEach(async function () {
    expectCount = 0;

    actorsManager = await deployContract("ActorsManager");
    signatureValidator = await deployContract("SignatureValidator", "Cruna", "1");

    const _baseTokenURI = "https://meta.cruna.cc/flexy-vault/v1/";
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

  const signSetProtector = async (tokenOwner, protector, timestamp, validFor) => {
    const message = {
      tokenOwner: tokenOwner.address,
      protector: protector.address,
      active: true,
      timestamp,
      validFor,
    };

    return makeSignature(
      chainId,
      signatureValidator.address,
      privateKeyByWallet[protector.address],
      "Auth",
      getTypesFromSelector("address tokenOwner,address protector,bool active,uint256 timestamp,uint256 validFor"),
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

  it("should revert if not activated", async function () {
    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await expect(flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1])).revertedWith("NotActivated()");
  });

  it("should create a vaults and add more assets to it", async function () {
    await flexiVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    // bob adds a stupidMonk token to his vaults
    await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));

    await flexiVault
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
      flexiVault.connect(alice).withdrawAssets(1, [2], [stupidMonk.address], [1], [1], [fred.address], 0, 0, 0)
    ).emit(stupidMonk, "Transfer");

    expect(await stupidMonk.balanceOf(fred.address)).equal(1);
  });

  it("should create a vaults and add generic assets in batch call", async function () {
    await flexiVault.connect(bob).activateAccount(1);

    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

    await flexiVault
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
    await flexiVault.connect(bob).activateAccount(1);

    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await stupidMonk.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await bulls.connect(bob).approve(flexiVaultManager.address, amount("10000"));
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);

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
    await flexiVault.connect(bob).activateAccount(1);

    await flexiVault.connect(bob).depositAssets(1, [0], [ethers.constants.AddressZero], [0], [0], {value: amount("1000")});
    expect((await flexiVaultManager.amountOf(1, [ethers.constants.AddressZero], [0]))[0]).equal(amount("1000"));

    const accountAddress = await flexiVaultManager.accountAddress(1);

    await expect((await ethers.provider.getBalance(accountAddress)).toString()).equal(amount("1000"));
  });

  it("should create a vaults, add assets to it, then eject and reinject again", async function () {
    await flexiVault.connect(bob).activateAccount(1);

    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await uselessWeapons.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2, 3], [particle.address, uselessWeapons.address], [2, 2], [1, 2]);
    expect((await flexiVaultManager.amountOf(1, [uselessWeapons.address], [2]))[0]).equal(2);

    // bob adds some bulls tokens to his vaults
    await bulls.connect(fred).approve(flexiVaultManager.address, amount("10000"));
    await flexiVault.connect(fred).depositAssets(1, [1], [bulls.address], [0], [amount("5000")]);
    expect((await flexiVaultManager.amountOf(1, [bulls.address], [0]))[0]).equal(amount("5000"));

    const trusteeAddress = await flexiVaultManager.trustee();
    const trustee = await deployUtils.attach("Trustee", trusteeAddress);

    expect(await trustee.ownerOf(1)).equal(flexiVaultManager.address);

    await expect(flexiVault.connect(bob).injectEjectedAccount(1)).revertedWith("NotAPreviouslyEjectedAccount()");

    await expect(flexiVault.connect(bob).ejectAccount(1, 0, 0, [])).emit(flexiVaultManager, "BoundAccountEjected").withArgs(1);

    expect(await trustee.ownerOf(1)).equal(bob.address);

    await expect(flexiVault.connect(bob).ejectAccount(1, 0, 0, [])).revertedWith("AccountAlreadyEjected()");

    await expect(flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [4], [1])).revertedWith("TrusteeNotFound()");

    await trustee.connect(bob).approve(flexiVault.address, 1);

    await expect(flexiVault.connect(bob).injectEjectedAccount(1))
      .emit(flexiVaultManager, "EjectedBoundAccountReInjected")
      .withArgs(1);

    expect(await trustee.ownerOf(1)).equal(flexiVaultManager.address);

    const accountAddress = await flexiVaultManager.accountAddress(1);

    await expect(flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [4], [1]))
      .emit(particle, "Transfer")
      .withArgs(bob.address, accountAddress, 4);

    expect(await particle.ownerOf(4)).equal(accountAddress);
  });

  it("should allow a transfer if a transfer initializer is pending", async function () {
    // expectCount = 1;
    await flexiVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    // bob transfers the protected to alice
    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);

    await expect(transferNft(flexiVault, alice)(alice.address, bob.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(alice.address, bob.address, 1);

    await setProtector(bob, mark);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");

    const timestamp = (await getTimestamp()) - 100;
    const validFor = 3600;
    const signature = await signSetProtector(bob, mark, timestamp, validFor);
    await expect(actorsManager.connect(bob).setProtector(mark.address, true, timestamp, validFor, signature)).revertedWith(
      "ProtectorAlreadySetByYou()"
    );
  });

  it("should not allow a transfer if a protector is active", async function () {
    await flexiVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await setProtector(bob, mark);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");
  });

  it("should allow a transfer of the protected if a valid protector's signature is provided", async function () {
    await flexiVault.connect(bob).activateAccount(1);
    // expectCount = 1;

    await setProtector(bob, john);

    expect(await actorsManager.isProtectorFor(bob.address, john.address)).equal(true);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");

    timestamp = (await getTimestamp()) - 100;
    validFor = 3600;

    const message = {
      tokenId: 1,
      to: alice.address,
      level: 2,
      timestamp,
      validFor,
    };

    signature = makeSignature(
      chainId,
      signatureValidator.address,
      privateKeyByWallet[john.address],
      "Auth",
      getTypesFromSelector("uint256 tokenId,address to,uint256 timestamp,uint256 validFor"),
      message
    );

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
    await flexiVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);

    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 2, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 2);

    await setProtector(bob, john);

    await expect(actorsManager.connect(bob).setSafeRecipient(fred.address, 2, 0, 0, 0)).revertedWith(
      "NotPermittedWhenProtectorsAreActive()"
    );

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should require a protector's signature to save a new safe recipient after a protector is active", async function () {
    await flexiVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);

    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await setProtector(bob, john);

    await expect(actorsManager.connect(bob).setSafeRecipient(fred.address, 2, 0, 0, 0)).revertedWith(
      "NotPermittedWhenProtectorsAreActive()"
    );

    timestamp = (await getTimestamp()) - 100;
    validFor = 3600;

    const message = {
      owner: bob.address,
      recipient: alice.address,
      level: 2,
      timestamp,
      validFor,
    };

    signature = makeSignature(
      chainId,
      signatureValidator.address,
      privateKeyByWallet[john.address],
      "Auth",
      getTypesFromSelector("address owner,address recipient,uint256 level,uint256 timestamp,uint256 validFor"),
      message
    );

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 2, timestamp, validFor, signature))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 2);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1))
      .emit(flexiVault, "Transfer")
      .withArgs(bob.address, alice.address, 1);
  });

  it("should not allow a transfer to a safe recipient level MEDIUM if a protector is active", async function () {
    await flexiVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 1, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 1);

    await setProtector(bob, john);

    await expect(transferNft(flexiVault, bob)(bob.address, alice.address, 1)).revertedWith("NotTransferable()");
  });

  it("should allow withdrawals when protectors are active if safe recipient", async function () {
    await flexiVault.connect(bob).activateAccount(1);

    // bob creates a vaults depositing a particle token
    await particle.connect(bob).setApprovalForAll(flexiVaultManager.address, true);
    await flexiVault.connect(bob).depositAssets(1, [2], [particle.address], [2], [1]);
    expect((await flexiVaultManager.amountOf(1, [particle.address], [2]))[0]).equal(1);

    await expect(actorsManager.connect(bob).setSafeRecipient(alice.address, 1, 0, 0, 0))
      .emit(actorsManager, "SafeRecipientUpdated")
      .withArgs(bob.address, alice.address, 1);

    await setProtector(bob, john);

    let account = await flexiVaultManager.accountAddress(1);

    await expect(flexiVault.connect(bob).withdrawAssets(1, [2], [particle.address], [2], [1], [alice.address], 0, 0, 0))
      .emit(particle, "Transfer")
      .withArgs(account, alice.address, 2);
  });
});
