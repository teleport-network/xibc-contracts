import "@nomiclabs/hardhat-waffle"
import "@openzeppelin/hardhat-upgrades"
import "@openzeppelin/hardhat-defender"
import "@nomiclabs/hardhat-ethers"
import "@typechain/hardhat"
import "hardhat-gas-reporter"
import "hardhat-contract-sizer"
import "hardhat-abi-exporter"
import "./tasks/Libraries"
import "./tasks/TssClient"
import "./tasks/TendermintClient"
import "./tasks/ClientManagerRC"
import "./tasks/ClientManagerAC"
import "./tasks/PacketRC"
import "./tasks/PacketAC"
import "./tasks/EndpointRC"
import "./tasks/EndpointAC"
import "./tasks/AccessManager"
import "./tasks/TestPayable"
import "./tasks/DeployAll"
import "./tasks/TestContracts"
import "./tasks/ERC20"
import "./tasks/Execute"

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
            accounts:['B8E1356DCC17B4C97D6E1A92C9CCDA2604A000FEB218902BD799BBBA41E30304']
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
        version: '0.8.13',
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