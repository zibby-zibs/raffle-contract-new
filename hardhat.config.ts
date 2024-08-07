import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import { vars } from "hardhat/config";

const ETHERSCAN_API_KEY = vars.get("ETHERSCAN_API_KEY");
const config: HardhatUserConfig = {
  defaultNetwork: "blast_sepolia",
  networks: {
    hardhat: {},
    blast_sepolia: {
      url: "https://blast-sepolia.g.alchemy.com/v2/txFmfkO2_FPtcQUhFYc_U2bFVGbc4hZk",
      accounts: {
        mnemonic:
          "ketchup choose fragile music because dry person vacant ride neutral leaf address",
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: "",
      },
    },
  },
  etherscan: {
    apiKey: {
      blast_sepolia: ETHERSCAN_API_KEY,
    },
    customChains: [
      {
        network: "blast_sepolia",
        chainId: 168587773,
        urls: {
          apiURL:
            "https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan",
          browserURL: "https://testnet.blastscan.io",
        },
      },
    ],
  },
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
};

export default config;
