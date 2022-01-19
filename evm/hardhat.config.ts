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
import "./tasks/deployRouting"
import "./tasks/deployTransfer"
import "./tasks/deployAccessManager"
import "./tasks/transfer"


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
            accounts: [
                "143B8C26CE93CFD6D7C15E028F24D8B511F7179CE2C5BD0C9DF9DF8CF6E144BE",
            ],
        },
        rinkeby: {
            url: 'https://rinkeby.infura.io/v3/023f2af0f670457d9c4ea9cb524f0810',
            gasPrice: 1500000000,
            chainId: 4,
            gas: 4100000,
            accounts: ['6995eddbc393d46b4bad576d1de73f5345782af4d003739176807ac3cbe969f6'],
        },
        bsctest: {
            url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
            gasPrice: 10000000000,
            chainId: 97,
            gas: 4100000,
            accounts: ['FB0536CF27B7F16EAB7F8BBD1771980E83ECE69F50BE30A7161D7E643645958D'],
        },
        ropsten: {
            url: 'https://ropsten.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
            gasPrice: 9000000000,
            chainId: 3,
            gas: 4100000,
            accounts: ['4f706b587618e242f45f9f67fb5cbb290902c7ff5828c468ee53138ef8a26945'],
        },
        testnet:  {
            url: 'HTTP://127.0.0.1:7545',
            gasPrice: 1500000000,
            chainId: 1337,
            gas: 4100000,
            accounts: ['6995eddbc393d46b4bad576d1de73f5345782af4d003739176807ac3cbe969f6'],
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