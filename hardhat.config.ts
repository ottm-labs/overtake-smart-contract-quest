import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-chai-matchers";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.20",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        }
    },
    networks: {
        timx: {
            url: "https://rpc.testnet.immutable.com",
            accounts: [],
            chainId: 13473
        },
        imx: {
            url: "https://rpc.immutable.com",
            accounts: [],
            chainId: 13371
        },
        sepolia: {
            url: `https://ethereum-sepolia-rpc.publicnode.com`,
            accounts: [],
        },
    }

};

export default config;