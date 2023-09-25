const {expect} = require("chai");
const {ethers} = require("hardhat");
const DeployUtils = require("../scripts/lib/DeployUtils");
let deployUtils;
const ethSigUtil = require("eth-sig-util");
const helpers = require("./helpers");
helpers.initEthers(ethers);
const {privateKeyByWallet, deployContract, getChainId, makeSignature} = helpers;

describe("SignatureValidator0", function () {
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
    validator = await deployContract("SignatureValidator0", "Cruna", "1");
  });

  // THIS MUST BE THE FIRST TEST HERE IF NOT validator.address IS NOT THE ONE THAT IS EXPECTED (due to Create2)
  // OR LAUNCHED AS only
  it("should validate signature with preset MetaMask signature", async function () {
    expect(mailTo.address).equal("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
    expect(validator.address).equal("0x5FbDB2315678afecb367f032d93F642f64180aa3");

    let signature =
      "0xe38ca8fb8e6a7ed40a0ea4228d5454d8e61e5d8232649ca3cfbd44b32530788d19a316b477138258b90dbcb4973f0bfc9e44511464bb04928e06645bf6391d1b1c";

    const message = {
      to: mailTo.address,
      contents: "very interesting",
    };

    expect(await validator.verify(signature, "0x90F79bf6EB2c4f870365E785982E1f101E93b906", message.to, message.contents)).equal(
      true
    );
  });

  it("should validate signature", async function () {
    let privateKey = privateKeyByWallet[wallet.address];

    const message = {
      to: mailTo.address,
      contents: "very interesting",
    };

    const signature = await makeSignature(
      chainId,
      validator.address,
      privateKey,
      "Mail",
      [
        {name: "to", type: "address"},
        {name: "contents", type: "string"},
      ],
      message
    );

    expect(await validator.verify(signature, wallet.address, message.to, message.contents)).equal(true);
  });
});
