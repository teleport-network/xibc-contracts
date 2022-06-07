import "@nomiclabs/hardhat-waffle"
import "@openzeppelin/hardhat-upgrades"
import "@openzeppelin/hardhat-defender"
import "@nomiclabs/hardhat-ethers"
import "@typechain/hardhat"
import "hardhat-gas-reporter"
import "hardhat-contract-sizer"
import "hardhat-abi-exporter"
import "./tasks/deployLibraries"
import "./tasks/deployTssClient"
import "./tasks/deployTendermintClient"
import "./tasks/deployClientManager"
import "./tasks/deployPacket"
import "./tasks/deployEndpoint"
import "./tasks/deployAccessManager"
import "./tasks/deployTestPayable"
import "./tasks/endpoint"
import "./tasks/deployAll"
import "./tasks/deployTestContracts"

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
        arbitrum: {
            url: '',
            gasPrice: 30000000,
            chainId: 421611,
            gas: 4100000,
        },
        teleport: {
            url: '',
            gasPrice: 5000000000,
            chainId: 8001,
            gas: 4100000,
        },
        rinkeby: {
            url: '',
            gasPrice: 1500000000,
            chainId: 4,
            gas: 4100000,
        },
        bsctest: {
            url: '',
            gasPrice: 10000000000,
            chainId: 97,
            gas: 4100000,
        },
    },
    solidity: {
        version: '0.8.9',
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