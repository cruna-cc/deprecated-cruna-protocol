const {expect} = require("chai");
const {ethers} = require("hardhat");
const DeployUtils = require("../scripts/lib/DeployUtils");
let deployUtils;
const ethSigUtil = require("eth-sig-util");
const helpers = require("./helpers");
helpers.initEthers(ethers);
const {privateKeyByWallet, deployContract, getChainId} = helpers;

const {domainType} = require("./helpers/eip712");

describe("SignatureValidator", function () {
  deployUtils = new DeployUtils(ethers);

  let chainId;

  let validator;
  let mailTo;
  let wallet;

  before(async function () {
    [mailTo, wallet] = await ethers.getSigners();
    chainId = await getChainId();
  });

  beforeEach(async function () {
    validator = await deployContract("SignatureValidator", "Cruna", "1");
  });

  // THIS MUST BE THE FIRST TEST IF NOT validator.address IS NOT THE ONE THAT IS EXPECTED (due to Create2)
  // OR LAUNCHED AS only
  it("should validate signature with preset MetaMask signature", async function () {
    expect(mailTo.address).equal("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
    expect(validator.address).equal("0x0E801D84Fa97b50751Dbf25036d067dCf18858bF");

    let signature =
      "0xf5760a6a7b7c23445d11d43c01d1258cd1a6e5cd9b26910533edf421baac65210a589663564830a22528bb88793aa2e1c47b0cd0a9907751b0366a055c5846541b";

    const message = {
      to: mailTo.address,
      contents: "very interesting",
    };

    expect(await validator.verify(signature, "0x90F79bf6EB2c4f870365E785982E1f101E93b906", message.to, message.contents)).equal(
      true
    );
  });

  it("should validate signature", async function () {
    let domain = {
      name: "Cruna",
      version: "1",
      chainId,
      verifyingContract: validator.address,
    };

    const message = {
      to: mailTo.address,
      contents: "very interesting",
    };

    const data = {
      types: {
        EIP712Domain: domainType(domain),
        Mail: [
          {name: "to", type: "address"},
          {name: "contents", type: "string"},
        ],
      },
      domain,
      primaryType: "Mail",
      message,
    };

    let privateKey = privateKeyByWallet[wallet.address];
    const privateKeyBuffer = Buffer.from(privateKey.slice(2), "hex");

    const signature = ethSigUtil.signTypedMessage(privateKeyBuffer, {data});

    expect(await validator.verify(signature, wallet.address, message.to, message.contents)).equal(true);
  });
});
