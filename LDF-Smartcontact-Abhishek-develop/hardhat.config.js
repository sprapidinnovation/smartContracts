require("@nomiclabs/hardhat-waffle");
require('dotenv').config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});
// const infura = 'https://rinkeby.infura.io/v3/a7fe863c5f044170ababe8300c20eb75';
// const private_key = '3f3af2e12d892e8ebc03763000286d4dce12a52f22b414f86fb27c42e183d9d2';

task("modify_block", "updates aqua infinity vault address", async (taskArgs, hre) => {
  for (let i = 0; i < 20; i++) await network.provider.send("evm_mine");
});



// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.7.5",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      },
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      },
      {
        version: "0.4.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      },
    ],
  },
  networks: {
    rinkeby: {
      url: process.env.RINKEBY_URL,
      chainId: 4,
      accounts: [`${process.env.PRIVATE_KEY}`],
      gas: "auto",
      gasPrice: "auto"
    }
  },
  mocha: {
    timeout: 200000
  }
  // matic: {
  //   url: process.env.RINKEBY_URL,
  //   accounts: [`${process.env.PRIVATE_KEY}`],
  //   gas: "auto",
  //   gasPrice: "auto"
  // }
};
