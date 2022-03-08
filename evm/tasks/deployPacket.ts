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
    .addParam("sourcechain", "sourceChain")
    .addParam("destchain", "sourceChain")
    .addParam("sequence", "sourceChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)
        let key = "receipts/" + taskArgs.sourcechain + "/" + taskArgs.destchain + "/sequences/" + taskArgs.sequence
        let packetRec = await packet.receipts(Buffer.from(key, "utf-8"))
        console.log(packetRec)
    })

task("queryCommit", "query commit")
    .addParam("packet", "packet address")
    .addParam("sourcechain", "sourceChain")
    .addParam("destchain", "sourceChain")
    .addParam("sequence", "sourceChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)
        let key = "acks/" + taskArgs.sourcechain + "/" + taskArgs.destchain + "/sequences/" + taskArgs.sequence
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
    .addParam("sourcechain", "sourceChain")
    .addParam("destchain", "sourceChain")
    .addParam("sequence", "sourceChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(String(PACKET_ADDRESS))

        let state = await packet.getAckStatus(taskArgs.sourcechain, taskArgs.destchain, taskArgs.sequence)
        console.log(state)
    })

module.exports = {}
