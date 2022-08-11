import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import { utils } from "ethers"
import { readFileSync } from 'fs'
import fs = require('fs');

const CLIENT_MANAGER_AC_ADDRESS = process.env.CLIENT_MANAGER_AC_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS

let client = require("../test/proto/compiled.js")

task("deployClientManagerAC", "Deploy Client Manager")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await hre.upgrades.deployProxy(
            clientManagerFactory,
            [
                String(ACCESS_MANAGER_ADDRESS),
            ]
        )
        await clientManager.deployed()
        console.log("Client Manager deployed to:", clientManager.address.toLocaleLowerCase())
        console.log("export CLIENT_MANAGER_AC_ADDRESS=%s", clientManager.address.toLocaleLowerCase())
        fs.appendFileSync('env.txt', 'export CLIENT_MANAGER_AC_ADDRESS=' + clientManager.address.toLocaleLowerCase() + '\n')
    })

task("upgradeClientManager", "Upgrade Client Manager")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await hre.upgrades.upgradeProxy(String(CLIENT_MANAGER_AC_ADDRESS), clientManagerFactory)
        await clientManager.deployed()
        console.log("Client Manager upgraded to:", clientManager.address)
        console.log("export CLIENT_MANAGER_ADDRESS=%s", clientManager.address)
    })

task("upgradeClientFromFile", "Upgrade Client")
    .addParam("clientstate", "HEX encoding client client")
    .addParam("consensusstate", "HEX encoding consensus state")
    .setAction(async (taskArgs, hre) => {
        const clientStatebytesHex = await readFileSync(taskArgs.clientstate)
        const clientStatebytes = Buffer.from(clientStatebytesHex.toString(), "hex")
        const consensusStateBytesHex = await readFileSync(taskArgs.consensusstate)
        const consensusStateBytes = Buffer.from(consensusStateBytesHex.toString(), "hex")
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_AC_ADDRESS))
        const clientStateObj = JSON.parse(clientStatebytes.toString())
        console.log("clientStateObj:", clientStateObj)
        const consensusStateObj = JSON.parse(consensusStateBytes.toString())
        console.log("consensusStateObj:", consensusStateObj)
        console.log("chainId:", clientStateObj.chain_id)
        const clientStateEncode = {
            chainId: clientStateObj.chain_id,
            trustLevel: {
                numerator: clientStateObj.trust_level.numerator,
                denominator: clientStateObj.trust_level.denominator
            },
            trustingPeriod: clientStateObj.trusting_period,
            unbondingPeriod: clientStateObj.unbonding_period,
            maxClockDrift: clientStateObj.max_clock_drift,
            latestHeight: {
                revisionNumber: clientStateObj.latest_height.revision_number,
                revisionHeight: clientStateObj.latest_height.revision_height
            },
            merklePrefix: {
                keyPrefix: Buffer.from("xibc"),
            },
            timeDelay: 10,
        }
        const clientState = client.ClientState.encode(clientStateEncode).finish()
        const consensusStateEncode = {
            timestamp: {
                secs: consensusStateObj.timestamp.secs,
                nanos: consensusStateObj.timestamp.nanos,
            },
            root: Buffer.from(consensusStateObj.root, "hex"),
            nextValidatorsHash: Buffer.from(consensusStateObj.nextValidatorsHash, "hex")
        }
        const consensusState = client.ConsensusState.encode(consensusStateEncode).finish()
        const result = await clientManager.upgradeClient(
            clientState,
            consensusState,
        )
        console.log(await result.wait())
    })

task("createClientFromFile", "create client from files")
    .addParam("client", "Client Address")
    .addParam("clientstate", "HEX encoding client client")
    .addParam("consensusstate", "HEX encoding consensus state")
    .setAction(async (taskArgs, hre) => {
        const clientStatebytesHex = await readFileSync(taskArgs.clientstate)
        const clientStatebytes = Buffer.from(clientStatebytesHex.toString(), "hex")
        const consensusStateBytesHex = await readFileSync(taskArgs.consensusstate)
        const consensusStateBytes = Buffer.from(consensusStateBytesHex.toString(), "hex")
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_AC_ADDRESS))
        const clientStateObj = JSON.parse(clientStatebytes.toString())
        console.log("clientStateObj:", clientStateObj)
        const consensusStateObj = JSON.parse(consensusStateBytes.toString())
        console.log("consensusStateObj:", consensusStateObj)
        console.log("chainId:", clientStateObj.chain_id)
        const clientStateEncode = {
            chainId: clientStateObj.chain_id,
            trustLevel: {
                numerator: clientStateObj.trust_level.numerator,
                denominator: clientStateObj.trust_level.denominator
            },
            trustingPeriod: clientStateObj.trusting_period,
            unbondingPeriod: clientStateObj.unbonding_period,
            maxClockDrift: clientStateObj.max_clock_drift,
            latestHeight: {
                revisionNumber: clientStateObj.latest_height.revision_number,
                revisionHeight: clientStateObj.latest_height.revision_height
            },
            merklePrefix: {
                keyPrefix: Buffer.from("xibc"),
            },
            timeDelay: 10,
        }
        const clientState = client.ClientState.encode(clientStateEncode).finish()
        const consensusStateEncode = {
            timestamp: {
                secs: consensusStateObj.timestamp.secs,
                nanos: consensusStateObj.timestamp.nanos,
            },
            root: Buffer.from(consensusStateObj.root, "hex"),
            nextValidatorsHash: Buffer.from(consensusStateObj.nextValidatorsHash, "hex")
        }
        const consensusState = client.ConsensusState.encode(consensusStateEncode).finish()
        const result = await clientManager.createClient(
            taskArgs.client,
            clientState,
            consensusState,
        )
        console.log(await result.wait())
    })

task("getTssCLient", "Get Tss CLient")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_AC_ADDRESS))
        const result = await clientManager.client()

        const tssCLientFactory = await hre.ethers.getContractFactory('TssClient')
        const tssCLient = await tssCLientFactory.attach(String(result))
        console.log(await tssCLient.getClientState())
    })

task("createTssCLient", "Create Tss CLient")
    .addParam("client", "Client Address")
    .addParam("pubkey", "pool pubkey")
    .addParam("partpubkeys", "part pubkeys")
    .addParam("pooladdress", "pool address")
    .addParam("threshold", "threshold")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_AC_ADDRESS))

        //support parse special array data for partpubkeys
        var re = /\[/gi;
        taskArgs.partpubkeys = taskArgs.partpubkeys.replace(re, "");
        re = /\]/gi;
        taskArgs.partpubkeys = taskArgs.partpubkeys.replace(re, "");
        taskArgs.partpubkeys = taskArgs.partpubkeys.split(",", 4);

        let clientStateBz = utils.defaultAbiCoder.encode(
            ["tuple(address,bytes,bytes[],uint64)"],
            [[taskArgs.pooladdress, taskArgs.pubkey, taskArgs.partpubkeys, taskArgs.threshold]],
        )
        const result = await clientManager.createClient(
            taskArgs.client,
            clientStateBz,
            "0x",
        )
        console.log(result)
    })

task("getTssByteQ", "QA Create Tss CLient")
    .setAction(async (taskArgs, hre) => {
        let threshold = 2
        let tss_address = "0x64f8fc6b26ec81762673ebb4e32e48b72821294f"
        let pubkey = "0xbfeae69c005221660bb8e20c11cc7bd3b4b8f3e85ef0356ed51905eaa172fcdd5480020eecb7fe85cd2aec618d2165f90e8b6480340f7273332206bf7d34d2f3"
        let partpubkeys = ["0x42417732b0e10b29aa8c5284c58136ac6726cbc1b5afc8ace6d6c4b03274cd01310b958a6dc5b27f2c1ad5c6595bffeac951c8407947d05166e687724d3890f7",
            "0xa926c961ab71a72466faa6abef8074e6530f4c56087c43087ab92da441cbb1e9d24dfc12a5e0b4a686897e50ffa9977b3c3eb13870dcd44335287c0777c71489",
            "0xc17413bbdf839a3732af84f61993c9a09d71f33a68f6fbf05ce53b66b0954929943184d65d8d02c11b7a70904805bcca6e3f3749d95e6438b168f2ed55768310",
            "0x28b5ba326397f2c0f689908bcf4fe198d842739441471fa96e43d4cdd495d9c9f138fed315b3744300fa1dd5599a9e21d12264f97b094f3a5f4b84be120a1c6a"]
        let clientStateBz = utils.defaultAbiCoder.encode(
            ["tuple(address,bytes,bytes[],uint64)"],
            [[tss_address, pubkey, partpubkeys, threshold]],
        )
        console.log(clientStateBz)
    })


task("getTssByteT", "Testnet Create Tss CLient")
.setAction(async (taskArgs, hre) => {
    let threshold = 0
    let tss_address = ""
    let pubkey = ""
    let partpubkeys = ["",
        "",
        "",
        ""]
    let clientStateBz = utils.defaultAbiCoder.encode(
        ["tuple(address,bytes,bytes[],uint64)"],
        [[tss_address, pubkey, partpubkeys, threshold]],
    )
    console.log(clientStateBz)
})

task("createClient", "create client with hex code")
    .addParam("client", "Client Address")
    .addParam("clientstate", "HEX encoding client client")
    .addParam("consensusstate", "HEX encoding consensus state")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_AC_ADDRESS))
        const clientStatebytes = Buffer.from(taskArgs.clientstate, "hex")
        const clientStateObj = JSON.parse(clientStatebytes.toString())
        const clientStateEncode = {
            chainId: clientStateObj.chainId,
            trustLevel: {
                numerator: clientStateObj.trustLevel.numerator,
                denominator: clientStateObj.trustLevel.denominator
            },
            trustingPeriod: clientStateObj.trustingPeriod,
            unbondingPeriod: clientStateObj.unbondingPeriod,
            maxClockDrift: clientStateObj.maxClockDrift,
            latestHeight: {
                revisionNumber: clientStateObj.latestHeight.revisionNumber,
                revisionHeight: clientStateObj.latestHeight.revisionHeight
            },
            merklePrefix: {
                keyPrefix: Buffer.from("xibc"),
            },
            timeDelay: 10,
        }
        const clientState = client.ClientState.encode(clientStateEncode).finish()
        const consensusStateBytes = Buffer.from(taskArgs.consensusstate, "hex")
        const consensusStateObj = JSON.parse(consensusStateBytes.toString())
        const consensusStateEncode = {
            timestamp: {
                secs: consensusStateObj.timestamp.secs,
                nanos: consensusStateObj.timestamp.nanos,
            },
            root: Buffer.from(consensusStateObj.root, "hex"),
            nextValidatorsHash: Buffer.from(consensusStateObj.nextValidatorsHash, "hex")
        }

        const consensusState = client.ConsensusState.encode(consensusStateEncode).finish()
        const result = await clientManager.createClient(
            taskArgs.client,
            clientState,
            consensusState,
        )
        console.log(result)
    })

task("updateClient", "update light client with header(hex)")
    .addParam("header", "HEX encoding header")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_AC_ADDRESS))
        const haeder = Buffer.from(taskArgs.header, "hex")
        const result = await clientManager.updateClient(haeder)
        console.log(await result.wait())
    })

task("lastheight", "get client latest height ")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_AC_ADDRESS))
        const result = await clientManager.getLatestHeight()
        console.log(result)
    })

task("getClientType", "Deploy Client Manager")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerAC')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_AC_ADDRESS))
        const result = await clientManager.getClientType()
        console.log(result)
    })

module.exports = {}
