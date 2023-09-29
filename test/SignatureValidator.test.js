const {expect} = require("chai");
const {ethers} = require("hardhat");
const DeployUtils = require("../scripts/lib/DeployUtils");
let deployUtils;
const ethSigUtil = require("eth-sig-util");
const helpers = require("./helpers");
const {getTimestamp} = require("./helpers");
helpers.initEthers(ethers);
const {privateKeyByWallet, deployContract, getChainId, makeSignature} = helpers;

describe("SignatureValidator", function () {
  deployUtils = new DeployUtils(ethers);

  let chainId;

  let validator;
  let mailTo;
  let wallet;
  let protector;

  before(async function () {
    [mailTo, wallet, tokenOwner, protector] = await ethers.getSigners();
    chainId = await getChainId();
  });

  beforeEach(async function () {
    validator = await deployContract("SignatureValidator", "Cruna", "1");
  });

  it("signSetProtector", async function () {
    const message = {
      tokenOwner: tokenOwner.address,
      protector: protector.address,
      active: true,
      timestamp: (await getTimestamp()) - 100,
      validFor: 3600,
    };

    const signature = await makeSignature(
      chainId,
      validator.address,
      privateKeyByWallet[protector.address],
      "Auth",
      [
        {name: "tokenOwner", type: "address"},
        {name: "protector", type: "address"},
        {name: "active", type: "bool"},
        {name: "timestamp", type: "uint256"},
        {name: "validFor", type: "uint256"},
      ],
      message
    );

    expect(
      await validator.signSetProtector(
        message.tokenOwner,
        message.protector,
        message.active,
        message.timestamp,
        message.validFor,
        signature
      )
    ).equal(protector.address);
  });
});
