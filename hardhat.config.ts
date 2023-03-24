import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";
import 'hardhat-abi-exporter';


dotenvConfig({ path: resolve("./.env") });

const PRIVATEKEY : string = process.env.PRIVATE_KEY as string;

const config: HardhatUserConfig = {
  networks: {
    Polygon: {
        url: "https://rpc.public.zkevm-test.net",
        accounts: [PRIVATEKEY],
    },
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.14",
  },
  abiExporter: {
    path: './abi',
  }
};

export default config;
