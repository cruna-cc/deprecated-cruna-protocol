const {expect} = require("chai");
const {deployContractUpgradeable, deployContract, amount, assertThrowsMessage} = require("./helpers");

describe("Protector", function () {
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
    coolProjectProtected = await deployContractUpgradeable("CoolProjectProtected", []);

    coolProjectTransparentVault = await deployContractUpgradeable("CoolProjectTransparentVault", [
      coolProjectProtected.address,
    ]);

    expect(await coolProjectProtected.getProtectedERC721InterfaceId()).to.equal("0x8dca4bea");

    expect(await coolProjectProtected.supportsInterface("0x8dca4bea")).to.be.true;

    await expect(coolProjectProtected.safeMint(bob.address, 1))
      .emit(coolProjectProtected, "Transfer")
      .withArgs(ethers.constants.AddressZero, bob.address, 1);

    await coolProjectProtected.safeMint(bob.address, 2);

    await coolProjectProtected.safeMint(bob.address, 3);
    await coolProjectProtected.safeMint(bob.address, 4);
    await coolProjectProtected.safeMint(alice.address, 5);
    await coolProjectProtected.safeMint(alice.address, 6);

    // erc721
    particle = await deployContract("Particle", "https://api.particle.com/");
    await particle.safeMint(alice.address, 1);
    await particle.safeMint(bob.address, 2);
    await particle.safeMint(john.address, 3);
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
});
