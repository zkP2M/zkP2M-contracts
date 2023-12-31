import * as dotenv from 'dotenv';

import '@typechain/hardhat'
import 'solidity-coverage'
import '@nomiclabs/hardhat-ethers'
import 'hardhat-deploy';
import '@nomiclabs/hardhat-etherscan';
import '@nomicfoundation/hardhat-chai-matchers'

import { HardhatUserConfig } from "hardhat/config";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      allowBlocksWithSameTimestamp: true,
    },
    localhost: {
      allowBlocksWithSameTimestamp: true,
    },
    scroll_sepolia: {
      url: "https://sepolia-rpc.scroll.io",
      accounts: [
        `0x${process.env.SCROLL_SEPOLIA_DEPLOY_PRIVATE_KEY}`,
      ],
      verify: {
        etherscan: {
          apiKey: process.env.SCROLLSCAN_API_KEY
        }
      }
    },
    arbitrum: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [
        `0x${process.env.ARBITRUM_DEPLOY_PRIVATE_KEY}`,
      ],
      verify: {
        etherscan: {
          apiKey: process.env.ETHERSCAN_API_KEY
        }
      }
    },
    mantle: {
      url: "https://rpc.testnet.mantle.xyz",
      accounts: [
        `0x${process.env.MANTLE_DEPLOY_PRIVATE_KEY}`,
      ],
      verify: {
        etherscan: {
          apiKey: process.env.MANTLESCAN_API_KEY
        }
      }
    },
    goerli: {
      url: "https://goerli.infura.io/v3/" + process.env.INFURA_TOKEN,
      // @ts-ignore
      accounts: [
        `0x${process.env.GOERLI_DEPLOY_PRIVATE_KEY}`,
      ],
      verify: {
        etherscan: {
          apiKey: process.env.ETHERSCAN_API_KEY
        }
      },
    },
    base: {
      url: "https://developer-access-mainnet.base.org",
      // @ts-ignore
      accounts: [
        `0x${process.env.BASE_DEPLOY_PRIVATE_KEY}`,
      ],
      verify: {
        etherscan: {
          apiUrl: "https://api.basescan.org/",
          apiKey: process.env.BASESCAN_API_KEY
        }
      },
    },
  },
  // @ts-ignore
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
};

export default config;
