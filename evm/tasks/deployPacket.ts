import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const ROUTING_ADDRESS = process.env.ROUTING_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS
const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const NOT_PROXY = process.env.NOT_PROXY

task("deployPacket", "Deploy Packet")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        if (NOT_PROXY) {
            const packet = await packetFactory.deploy()
            await packet.deployed()
            console.log("Packet deployed  !")
            console.log("export PACKET_ADDRESS=%s", packet.address.toLocaleLowerCase())
        } else {
            const packet = await hre.upgrades.deployProxy(
                packetFactory,
                [
                    String(CLIENT_MANAGER_ADDRESS),
                    String(ROUTING_ADDRESS),
                    String(ACCESS_MANAGER_ADDRESS)
                ]
            )
            await packet.deployed()
            console.log("Packet deployed to:", packet.address.toLocaleLowerCase())
            console.log("export PACKET_ADDRESS=%s", packet.address.toLocaleLowerCase())
            fs.appendFileSync('env.txt', 'export PACKET_ADDRESS=' + packet.address.toLocaleLowerCase() + '\n')
        }


    })

task("queryRecipt", "query recipt")
    .addParam("packet", "packet address")
    .addParam("srcchain", "srcChain")
    .addParam("dstchain", "srcChain")
    .addParam("sequence", "srcChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)
        let key = taskArgs.srcchain + "/" + taskArgs.dstchain + "/" + taskArgs.sequence
        let packetRec = await packet.receipts(Buffer.from(key, "utf-8"))
        console.log(packetRec)
    })

task("queryCommit", "query commit")
    .addParam("packet", "packet address")
    .addParam("srcchain", "srcChain")
    .addParam("dstchain", "srcChain")
    .addParam("sequence", "srcChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)
        let key = "commitments/" + taskArgs.srcchain + "/" + taskArgs.dstchain + "/sequences/" + taskArgs.sequence
        let packetRec = await packet.commitments(Buffer.from(key, "utf-8"))
        console.log(packetRec)
    })

task("queryRole", "query role")
    .addParam("packet", "packet address")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)

        let roleHash = await packet.MULTISEND_ROLE()
        console.log(roleHash)
    })

task("getAckStatus", "get ack status")
    .addParam("srcchain", "srcChain")
    .addParam("dstchain", "srcChain")
    .addParam("sequence", "srcChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(String(PACKET_ADDRESS))

        let state = await packet.getAckStatus(taskArgs.srcchain, taskArgs.dstchain, taskArgs.sequence)
        console.log(state)
    })

task("getPacketFee", "query packet fee")
    .addParam("packet", "packet address")
    .addParam("srcchain", "srcChain")
    .addParam("dstchain", "srcChain")
    .addParam("sequence", "srcChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)

        let key = taskArgs.srcchain + "/" + taskArgs.dstchain + "/" + taskArgs.sequence
        let Fees = await packet.packetFees(Buffer.from(key, "utf-8"))
        console.log(Fees)
    })

task("addPacketFee", "set packet fee")
    .addParam("packet", "packet address")
    .addParam("src", "source chain name")
    .addParam("dst", "destination chain name")
    .addParam("sequence", "sequence")
    .addParam("amount", "amount")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)

        let tx = await packet.addPacketFee(
            taskArgs.src,
            taskArgs.dst,
            taskArgs.sequence,
            taskArgs.amount,
        )

        console.log(tx)
        console.log("txHash: ", tx.hash)
        console.log("blockHash: ", tx.blockHash)
    })

module.exports = {}