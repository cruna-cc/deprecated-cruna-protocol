const {expect} = require("chai");
const {addr0, assertThrowsMessage} = require("./helpers");

describe("ClusteredNFT", function () {
  let ClusteredNFT, clusteredNFT, owner, owner2, owner3, bob, alice, fred, john;

  beforeEach(async function () {
    ClusteredNFT = await ethers.getContractFactory("ERC7108");

    [owner, owner2, owner3, bob, alice, fred, john] = await ethers.getSigners();

    clusteredNFT = await ClusteredNFT.deploy("ClusteredNFT", "cNFT");
    await clusteredNFT.deployed();

    expect(await clusteredNFT.getInterfaceId()).equal("0x4d676ad4");
  });

  it("Deploys contracts, mints tokens and checks ownerships", async function () {
    await expect(clusteredNFT.clusterOf(1)).revertedWith("ClusterNotFound()");

    await expect(
      clusteredNFT.connect(owner2).addCluster("Jolly Token", "JT", "https://jolly-token.cc/meta/", 1000, addr0)
    ).revertedWith("ZeroAddress()");

    await expect(
      clusteredNFT.connect(owner2).addCluster("Jolly Token", "JT", "https://jolly-token.cc/meta/", 100000, owner2.address)
    ).revertedWith("SizeTooLarge()");

    await expect(
      clusteredNFT.connect(owner2).addCluster("Jolly Token", "JT", "https://jolly-token.cc/meta/", 2222, owner2.address)
    )
      .to.emit(clusteredNFT, "ClusterAdded")
      .withArgs(0, "Jolly Token", "JT", "https://jolly-token.cc/meta/", 2222, owner2.address);

    await expect(clusteredNFT.connect(owner3).addCluster("Bud Token", "BT", "https://bud-token.cc/meta/", 5000, owner3.address))
      .to.emit(clusteredNFT, "ClusterAdded")
      .withArgs(1, "Bud Token", "BT", "https://bud-token.cc/meta/", 5000, owner3.address);

    expect(await clusteredNFT.clustersCount()).equal(2);
    expect(await clusteredNFT.nameOf(0)).equal("Jolly Token");
    expect(await clusteredNFT.nameOf(1)).equal("Bud Token");
    expect(await clusteredNFT.symbolOf(1)).equal("BT");
    expect(await clusteredNFT.symbolOf(2)).equal("");
    expect(await clusteredNFT.clusterOwner(0)).equal(owner2.address);

    await expect(clusteredNFT.connect(owner2).mint(0, bob.address))
      .emit(clusteredNFT, "Transfer")
      .withArgs(addr0, bob.address, 1);

    await expect(clusteredNFT.connect(owner3).mint(1, alice.address))
      .emit(clusteredNFT, "Transfer")
      .withArgs(addr0, alice.address, 2223);

    await expect(clusteredNFT.connect(owner3).mint(1, fred.address))
      .emit(clusteredNFT, "Transfer")
      .withArgs(addr0, fred.address, 2224);

    await expect(clusteredNFT.connect(owner3).mint(1, john.address))
      .emit(clusteredNFT, "Transfer")
      .withArgs(addr0, john.address, 2225);

    await expect(clusteredNFT.connect(owner2).mint(1, bob.address)).revertedWith("NotClusterOwner()");

    await expect(clusteredNFT.connect(owner2).mint(3, bob.address)).revertedWith("ClusterNotFound()");

    expect(await clusteredNFT.clusterOf(2223)).equal(1);
    expect(await clusteredNFT.clusterOf(4400)).equal(1);
    await expect(clusteredNFT.clusterOf(222300)).revertedWith("ClusterNotFound()");

    const range = await clusteredNFT.rangeOf(0);

    expect(range[0]).equal(1);
    expect(range[1]).equal(2222);

    expect(await clusteredNFT.normalizedTokenId(1)).equal(1);
    expect(await clusteredNFT.normalizedTokenId(2223)).equal(1);
    expect(await clusteredNFT.normalizedTokenId(2224)).equal(2);
    expect(await clusteredNFT.normalizedTokenId(2225)).equal(3);

    await expect(clusteredNFT.normalizedTokenId(222600)).revertedWith("ClusterNotFound()");

    expect(await clusteredNFT.tokenURI(2224)).equal("https://bud-token.cc/meta/2");

    // verify that the binary search works as expected

    let k = (await clusteredNFT.rangeOf(1))[1].toNumber();
    let k0 = k;
    let l = 2;
    for (let i = 0, j = 1000; i < 79; i++, j += 33) {
      let owner = i % 2 ? owner2 : owner3;
      await clusteredNFT.connect(owner3).addCluster("Some Token", "ST", "https://some-token.cc/meta/", j, owner.address);
      let v = k + j - 10;
      const result = await clusteredNFT.clusterOf(v);
      expect(result).equal(i + 2);
      k += j - 1;
    }

    k = k0;
    j = 1000;
    for (let i = 0, j = 1000; i < 79; i++, j += 33) {
      let v = k + j - 10;
      const result = await clusteredNFT.clusterOf(v);
      expect(result).equal(i + 2);
      k += j - 1;
    }

    let myClusters = (await clusteredNFT.clustersByOwner(owner3.address)).map((e) => e.toNumber());
    expect(myClusters.length).equal(41);
    expect(myClusters[10]).equal(20);

    myClusters = (await clusteredNFT.clustersByOwner(owner2.address)).map((e) => e.toNumber());
    expect(myClusters.length).equal(40);
    expect(myClusters[10]).equal(21);

    await expect(clusteredNFT.connect(owner2).transferClusterOwnership(0, addr0)).revertedWith("ZeroAddress()");

    await expect(clusteredNFT.connect(owner3).transferClusterOwnership(0, bob.address)).revertedWith("NotClusterOwner()");

    await expect(clusteredNFT.connect(owner2).transferClusterOwnership(0, fred.address))
      .emit(clusteredNFT, "ClusterOwnershipTransferred")
      .withArgs(0, fred.address);
  });
});
