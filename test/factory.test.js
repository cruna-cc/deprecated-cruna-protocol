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

describe("CrunaClusterFactory", function () {
  const deployUtils = new DeployUtils(ethers);

  let crunaVault, factory, tokenUtils;
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

    const _baseTokenURI = "https://meta.cruna.cc/vault/v1/";
    crunaVault = await deployContract("CrunaVault", _baseTokenURI, tokenUtils.address);
    expect(await crunaVault.version()).to.equal("1.0.0");
    await crunaVault.addCluster("Cruna Vault V1", "CRUNA", _baseTokenURI, 100000, owner.address);

    factory = await deployContractUpgradeable("CrunaClusterFactory", [crunaVault.address]);

    await crunaVault.allowFactoryFor(factory.address, 0);

    usdc = await deployContract("USDCoin");
    usdt = await deployContract("TetherUSD");

    await usdc.mint(bob.address, normalize("900"));
    await usdt.mint(alice.address, normalize("600", 6));

    await expect(factory.setPrice(990)).emit(factory, "PriceSet").withArgs(990);

    await expect(factory.setStableCoin(usdc.address, true)).emit(factory, "StableCoinSet").withArgs(usdc.address, true);

    await expect(factory.setStableCoin(usdt.address, true)).emit(factory, "StableCoinSet").withArgs(usdt.address, true);
  });

  async function buyVault(token, amount, buyer) {
    let price = await factory.finalPrice(token.address);
    await token.connect(buyer).approve(factory.address, price.mul(amount));

    await expect(factory.connect(buyer).buyVaults(token.address, amount))
      .emit(crunaVault, "Transfer")
      .withArgs(addr0, buyer.address, 1)
      .emit(crunaVault, "Transfer")
      .withArgs(addr0, buyer.address, 2)
      .emit(token, "Transfer")
      .withArgs(buyer.address, factory.address, price.mul(amount).toString());
  }

  it("should allow bob and alice to purchase some vaults", async function () {
    await buyVault(usdc, 2, bob);
    await buyVault(usdt, 2, alice);

    let price = await factory.finalPrice(usdc.address);
    expect(price.toString()).to.equal("9900000000000000000");
    price = await factory.finalPrice(usdt.address);
    expect(price.toString()).to.equal("9900000");

    await expect(factory.withdrawProceeds(fred.address, usdc.address, normalize("10")))
      .emit(usdc, "Transfer")
      .withArgs(factory.address, fred.address, normalize("10"));
    await expect(factory.withdrawProceeds(fred.address, usdc.address, 0))
      .emit(usdc, "Transfer")
      .withArgs(factory.address, fred.address, amount("9.8"));
  });
});
