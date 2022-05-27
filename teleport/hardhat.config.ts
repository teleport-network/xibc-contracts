import "@nomiclabs/hardhat-waffle"
import "@openzeppelin/hardhat-upgrades"
import "@typechain/hardhat"
import "hardhat-gas-reporter"
import "hardhat-contract-sizer"
import "hardhat-abi-exporter"
import "./tasks/crossChain"

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
        localhost: {
            url: 'http://localhost:8545',
            gasPrice: 5000000000,
            chainId: 9000,
            gas: 4100000,
        },
        qa: {
            url: '',
            gasPrice: 5000000000,
            chainId: 7001,
            gas: 4100000,
        },
        teleport: {
            url: '',
            gasPrice: 5000000000,
            chainId: 8001,
            gas: 4100000,
        },
    },
    solidity: {
        version: '0.6.8',
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