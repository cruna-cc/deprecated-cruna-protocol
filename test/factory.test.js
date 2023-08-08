const chai = require("chai");
const {deployContract, amount, normalize, deployContractUpgradeable, addr0} = require("./helpers");
const DeployUtils = require("../scripts/lib/DeployUtils");

let expectCount = 0;

const expect = (actual) => {
  if (expectCount > 0) {
    console.log(`> ${expectCount++}`);
  }
  return chai.expect(actual);
};

describe("VaultFactory", function () {
  const deployUtils = new DeployUtils(ethers);

  let flexiVault, flexiVaultManager, factory;
  let registry, wallet, proxyWallet, tokenUtils, actorsManager;
  // mocks
  let usdc, usdt;
  let notAToken;
  // wallets
  let owner, bob, alice, fred;

  before(async function () {
    [owner, bob, alice, fred] = await ethers.getSigners();
  });

  beforeEach(async function () {
    expectCount = 0;
    tokenUtils = await deployContract("TokenUtils");
    expect(await tokenUtils.version()).to.equal("1.0.0");

    actorsManager = await deployContract("ActorsManager");

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

    factory = await deployContractUpgradeable("VaultFactory", [flexiVault.address]);

    await flexiVault.setFactory(factory.address);

    usdc = await deployContract("USDCoin");
    usdt = await deployContract("TetherUSD");

    await usdc.mint(bob.address, normalize("900"));
    await usdt.mint(alice.address, normalize("600", 6));

    await expect(factory.setPrice(990)).emit(factory, "PriceSet").withArgs(990);

    await expect(factory.setStableCoin(usdc.address, true)).emit(factory, "StableCoinSet").withArgs(usdc.address, true);

    await expect(factory.setStableCoin(usdt.address, true)).emit(factory, "StableCoinSet").withArgs(usdt.address, true);
  });

  async function buyVault(token, amount, buyer, promoCode = "") {
    let price = await factory.finalPrice(token.address, promoCode);
    await token.connect(buyer).approve(factory.address, price.mul(amount));

    await expect(factory.connect(buyer).buyVaults(token.address, amount, promoCode))
      .emit(flexiVault, "Transfer")
      .withArgs(addr0, buyer.address, 1)
      .emit(flexiVault, "Transfer")
      .withArgs(addr0, buyer.address, 2)
      .emit(token, "Transfer")
      .withArgs(buyer.address, factory.address, price.mul(amount));
  }

  it("should allow bob and alice to purchase some vaults", async function () {
    await buyVault(usdc, 2, bob);
    await buyVault(usdt, 2, alice);

    let price = await factory.finalPrice(usdc.address, "");
    expect(price.toString()).to.equal("9900000000000000000");
    price = await factory.finalPrice(usdt.address, "");
    expect(price.toString()).to.equal("9900000");

    await expect(factory.withdrawProceeds(fred.address, usdc.address, normalize("10")))
      .emit(usdc, "Transfer")
      .withArgs(factory.address, fred.address, normalize("10"));
    await expect(factory.withdrawProceeds(fred.address, usdc.address, 0))
      .emit(usdc, "Transfer")
      .withArgs(factory.address, fred.address, amount("9.8"));
  });

  it("should allow bob and alice to purchase some vaults with a promoCode", async function () {
    const promoCode = "TheRoundTable".toLowerCase();
    await factory.setPromoCode(promoCode, 10);

    await buyVault(usdc, 2, bob);
    await buyVault(usdt, 2, alice, promoCode);

    let price = await factory.finalPrice(usdc.address, "");
    expect(price.toString()).to.equal("9900000000000000000");
    price = await factory.finalPrice(usdt.address, promoCode);
    expect(price.toString()).to.equal("8910000");

    await expect(factory.withdrawProceeds(fred.address, usdc.address, normalize("10")))
      .emit(usdc, "Transfer")
      .withArgs(factory.address, fred.address, normalize("10"));
    await expect(factory.withdrawProceeds(fred.address, usdc.address, 0))
      .emit(usdc, "Transfer")
      .withArgs(factory.address, fred.address, amount("9.8"));
  });
});
