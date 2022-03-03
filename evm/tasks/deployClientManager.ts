import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import { utils } from "ethers"
import { readFileSync } from 'fs'
import fs = require('fs');

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS

let client = require("../test/proto/compiled.js")

task("deployClientManager", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await hre.upgrades.deployProxy(
            clientManagerFactory,
            [
                taskArgs.chain,
                String(ACCESS_MANAGER_ADDRESS),
            ]
        )
        await clientManager.deployed()
        console.log("Client Manager deployed to:", clientManager.address.toLocaleLowerCase())
        console.log("export CLIENT_MANAGER_ADDRESS=%s", clientManager.address.toLocaleLowerCase())
        fs.appendFileSync('env.txt', 'export CLIENT_MANAGER_ADDRESS='+clientManager.address.toLocaleLowerCase()+'\n')
    })

task("upgradeClientManager", "Upgrade Client Manager")
    .addParam("chain", "Chain Name")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await hre.upgrades.upgradeProxy(String(CLIENT_MANAGER_ADDRESS), clientManagerFactory)
        await clientManager.deployed()
        console.log("Client Manager upgraded to:", clientManager.address)
        console.log("export CLIENT_MANAGER_ADDRESS=%s", clientManager.address)
    })

task("upgradeClient", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .addParam("clientstate", "HEX encoding client client")
    .addParam("consensusstate", "HEX encoding consensus state")
    .setAction(async (taskArgs, hre) => {
        const clientStatebytesHex = await readFileSync(taskArgs.clientstate)
        const clientStatebytes = Buffer.from(clientStatebytesHex.toString(), "hex")
        const consensusStateBytesHex = await readFileSync(taskArgs.consensusstate)
        const consensusStateBytes = Buffer.from(consensusStateBytesHex.toString(), "hex")
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
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
            taskArgs.chain,
            clientState,
            consensusState,
        )
        console.log(await result.wait())
    })
task("createClientFromFile", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .addParam("client", "Client Address")
    .addParam("clientstate", "HEX encoding client client")
    .addParam("consensusstate", "HEX encoding consensus state")
    .setAction(async (taskArgs, hre) => {
        const clientStatebytesHex = await readFileSync(taskArgs.clientstate)
        const clientStatebytes = Buffer.from(clientStatebytesHex.toString(), "hex")
        const consensusStateBytesHex = await readFileSync(taskArgs.consensusstate)
        const consensusStateBytes = Buffer.from(consensusStateBytesHex.toString(), "hex")
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
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
            taskArgs.chain,
            taskArgs.client,
            clientState,
            consensusState,
        )
        console.log(await result.wait())
    })

task("getTssCLient", "Get Tss CLient")
    .addParam("chain", "Chain Name")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))

        const result = await clientManager.clients(taskArgs.chain)

        const tssCLientFactory = await hre.ethers.getContractFactory('TssClient')
        const tssCLient = await tssCLientFactory.attach(String(result))
        console.log(await tssCLient.getClientState())
    })

task("createTssCLient", "Create Tss CLient")
    .addParam("chain", "Chain Name")
    .addParam("client", "Client Address")
    .addParam("pubkey", "pool pubkey")
    .addParam("partpubkeys", "part pubkeys")
    .addParam("pooladdress", "pool address")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
        let clientStateBz = utils.defaultAbiCoder.encode(
            ["tuple(address,bytes,bytes[])"],
            [[taskArgs.pooladdress, taskArgs.pubkey, taskArgs.partpubkeys]],
        )
        const result = await clientManager.createClient(
            taskArgs.chain,
            taskArgs.client,
            clientStateBz,
            "0x",
        )
        console.log(result)
    })

task("createClient", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .addParam("client", "Client Address")
    .addParam("clientstate", "HEX encoding client client")
    .addParam("consensusstate", "HEX encoding consensus state")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
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
            taskArgs.chain,
            taskArgs.client,
            clientState,
            consensusState,
        )
        console.log(result)
    })

task("registerRelayer", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .addParam("relayer", "Relayer Address")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
        const result = await clientManager.registerRelayer(taskArgs.chain, taskArgs.relayer)
        console.log(result)
    })

task("updateClient", "Deploy Client Manager")
    .addParam("chain", "chain name")
    // .addParam("header", "HEX encoding header")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
        const haeder = Buffer.from("0ad2040a95030a02080b120f74656c65706f72745f393030302d3118be26220b08dba9a8900610c8dea97e2a480a204f3af06ff38065cd1c3210f923be3a869bf6fc03d11561102b07fb539446add112240801122035bbd4b42559f6d2d1822624cfa71aac4898eaf5556355bbd491fdc6db93ae55322048defa23a1fe14cadc824d5a7d90170c6426fb2db6268219ec44eced41547fcf3a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85542203ac64116f660082831134eb00ddb75b8ab360c2257133f1856097728d0c132734a203ac64116f660082831134eb00ddb75b8ab360c2257133f1856097728d0c132735220048091bc7ddc283f77bfbf91d73c44da58c3df8a9cbc867405d8b7f3daada22f5a207d6411ededa8ca60d1dfc822d525e84599529e9f2ef3af6b1fdfe9fd3d0ec4296220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8556a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85572141a5166c6279a04d93dbd6b1935ab568cbbfe75bc12b70108be261a480a2026dbbde61802c3e166929427ba1ef4f985fae9fde9bd6bdde17e2e84af5b6af11224080112201e452531f5658e894d12e46121a1874caf568ea7b4bd37f8b4cc37a4737e7a442268080212141a5166c6279a04d93dbd6b1935ab568cbbfe75bc1a0c08e0a9a8900610c8f8f5c3012240523009fecc502ec8d210ceb58ec744dfcac5e5621bd5e76a0d49fdd8faec095914f8f6e1110c9f8be8f616e1a397d8f053a2be8a4af143e826fca2c0e202330e1290010a420a141a5166c6279a04d93dbd6b1935ab568cbbfe75bc12220a209e3029e48491d29f560491d2a118781522a1e3a5fae4d7ee580dd1ee1abf4667188080e983b1de1612420a141a5166c6279a04d93dbd6b1935ab568cbbfe75bc12220a209e3029e48491d29f560491d2a118781522a1e3a5fae4d7ee580dd1ee1abf4667188080e983b1de16188080e983b1de161a0508011092262290010a420a141a5166c6279a04d93dbd6b1935ab568cbbfe75bc12220a209e3029e48491d29f560491d2a118781522a1e3a5fae4d7ee580dd1ee1abf4667188080e983b1de1612420a141a5166c6279a04d93dbd6b1935ab568cbbfe75bc12220a209e3029e48491d29f560491d2a118781522a1e3a5fae4d7ee580dd1ee1abf4667188080e983b1de16188080e983b1de16", "hex")
        const result = await clientManager.updateClient(taskArgs.chain, haeder)
        console.log(await result.wait())
    })

task("getRelayers", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .addParam("relayer", "Relayer Address")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
        const result = await clientManager.relayers(taskArgs.chain, taskArgs.relayer)
        console.log(result)
    })

task("lastheight", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
        const result = await clientManager.getLatestHeight(taskArgs.chain)
        console.log(result)
    })

task("getClient", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
        const result = await clientManager.getClient(taskArgs.chain)
        console.log(await result.wait())
    })

task("getChainName", "Deploy Client Manager")
    .addParam("chain", "Chain Name")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
        const result = await clientManager.getChainName()
        console.log(result)
    })

module.exports = {}
