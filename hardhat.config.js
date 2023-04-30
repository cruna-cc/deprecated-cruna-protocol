const {requirePath} = require("require-or-mock");
// if missed, it sets a mock up
requirePath(".env");
requirePath("export/deployed.json", "{}");

require("dotenv").config();
require("cryptoenv").parse(() => process.env.NODE_ENV !== "test");

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@openzeppelin/hardhat-upgrades");

if (process.env.GAS_REPORT === "yes") {
  require("hardhat-gas-reporter");
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      blockGasLimit: 10000000,
    },
    localhost: {
      url: "http://localhost:8545",
      chainId: 1337,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.FOR_TESTNET, process.env.FOR_TESTNET_NEW],
    },
    ethereum: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.NDUJA],
    },
    mumbai: {
      url: "https://matic-mumbai.chainstacklabs.com",
      chainId: 80001,
      gasPrice: 20000000000,
      accounts: [process.env.FOR_TESTNET, process.env.FOR_TESTNET_NEW],
    },
    matic: {
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      chainId: 137,
      accounts: [process.env.NDUJA],
    },
  },
  etherscan: {
    // apiKey: process.env.ETHERSCAN_KEY
    apiKey: process.env.POLYGONSCAN_APIKEY,
    // apiKey: process.env.BSCSCAN_KEY
  },
  gasReporter: {
    currency: "USD",
    coinmarketcap: process.env.COIN_MARKET_CAP_APIKEY,
  },
};
