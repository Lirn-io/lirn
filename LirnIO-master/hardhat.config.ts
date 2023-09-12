import fs from "fs";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import '@openzeppelin/hardhat-upgrades';
import 'dotenv/config';
import "@nomiclabs/hardhat-etherscan";


import example from "./tasks/example";

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.trim().split("="));
}

task("example", "Example task").setAction(example);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.13",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "hardhat",
	networks: {
		localhost: {
			url: "http://127.0.0.1:8545",
		},
		hardhat: {},
    goerli: {
      url: process.env.PROVIDER_GOERLI,
      accounts: process.env.PRIVATE_KEY1 !== undefined && process.env.PRIVATE_KEY2 != undefined ? [process.env.PRIVATE_KEY1, process.env.PRIVATE_KEY2] : []
    },
    mainnet: {
      url: process.env.PROVIDER_MAINNET,
      accounts: process.env.PRIVATE_KEY1 !== undefined && process.env.PRIVATE_KEY2 != undefined ? [process.env.PRIVATE_KEY1, process.env.PRIVATE_KEY2] : []
    }
  },
  etherscan: {
		apiKey: process.env.ETHERSCAN_KEY != undefined ? process.env.ETHERSCAN_KEY : "",
	},
  paths: {
    sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
    cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
  },
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
};

export default config;
