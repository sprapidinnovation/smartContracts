/**
 * @type import('hardhat/config').HardhatUserConfig
 */
// require('@nomiclabs/hardhat-ethers')
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

// const ROPSTEN_URL = process.env.ROPSTEN_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
// const YOUR_ETHERSCAN_API_KEY = process.env.YOUR_ETHERSCAN_API_KEY;
module.exports = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    avaxTestnet: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    // avaxMainnet: {},
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      gas: 2100000,
      gasPrice: 20000000000,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    // ropsten: {
    //   url: ROPSTEN_URL,
    //   accounts: [`0x${PRIVATE_KEY}`],
    // },
    ganache: {
      url: "HTTP://127.0.0.1:7545",
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
  etherscan: {
    // Your API key for Etherscan
    apiKey: {
      bscTestnet: "YF8MEH3UF4G1MQ58I3S16YWU7ITEEMWZAB",
      avalancheFujiTestnet: "35HDSRK2JYT8WB1PZ79UN1VJUV1GCYTRA2",
    },
  },
};
