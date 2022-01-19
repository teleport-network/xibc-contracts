import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import { utils } from "ethers"
import { readFileSync } from 'fs'

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
        console.log("Client Manager deployed to:", clientManager.address)
        console.log("export CLIENT_MANAGER_ADDRESS=%s", clientManager.address)
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
    .addParam("pubkey", "Tss pubkey")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))

        let clientStateBz = utils.defaultAbiCoder.encode(
            ["tuple(address,bytes)"],
            [["0x0000000000000000000000000000000000000000", taskArgs.pubkey]],
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
    .addParam("header", "HEX encoding header")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await clientManagerFactory.attach(String(CLIENT_MANAGER_ADDRESS))
        const result = await clientManager.updateClient(taskArgs.chain, Buffer.from(taskArgs.header, "hex"))
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
