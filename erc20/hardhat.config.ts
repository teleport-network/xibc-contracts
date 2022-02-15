import "@nomiclabs/hardhat-waffle"
import "@openzeppelin/hardhat-upgrades"
import "@typechain/hardhat"
import "hardhat-gas-reporter"
import "hardhat-contract-sizer"
import "hardhat-abi-exporter"
import "./tasks/token"

module.exports = {
    defaultNetwork: 'hardhat',
    defender: {
        apiKey: "[apiKey]",
        apiSecret: "[apiSecret]",
    },
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
        },
        teleport: {
            url: 'http://localhost:8545',
            gasPrice: 2000000000,
            chainId: 9000,
            gas: 4100000,

        },
        rinkeby: {
            url: 'https://rinkeby.infura.io/v3/023f2af0f670457d9c4ea9cb524f0810',
            gasPrice: 1500000000,
            chainId: 4,
            gas: 4100000,
            accounts: ['91e9f90b378f45a41ff6e7b31d029067073085977b849f29ac817fdc379d547a'],
        },
        bsctest: {
            url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
            gasPrice: 10000000000,
            chainId: 97,
            gas: 4100000,
            accounts: ['f679139cd3b70ee08f6be85ebd1f6aacffcc57e0cbe3edf3770f34e6a6641a67'],
        },
    },
    solidity: {
        version: '0.8.0',
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000,
            },
        }
    },
    gasReporter: {
        enabled: true,
        showMethodSig: true,
        maxMethodDiff: 10,
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    abiExporter: {
        path: './abi',
        clear: true,
        spacing: 4,
    }
}