import "@nomiclabs/hardhat-web3"
import { tasks } from "hardhat"
import { task } from "hardhat/config"
let client = require("../test/proto/compiled.js")

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const ROUTING_ADDRESS = process.env.ROUTING_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS

task("deployPacket", "Deploy Packet")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await hre.upgrades.deployProxy(
            packetFactory,
            [
                String(CLIENT_MANAGER_ADDRESS),
                String(ROUTING_ADDRESS),
                String(ACCESS_MANAGER_ADDRESS)
            ]
        )
        await packet.deployed()
        console.log("Packet deployed to:", packet.address)
        console.log("export PACKET_ADDRESS=%s", packet.address)
    })

task("queryRecipt", "Packet")
    .addParam("packet","packet address")
    .addParam("sourcechain","sourceChain")
    .addParam("destchain","sourceChain")
    .addParam("sequence","sourceChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)
        let key = "receipts/" + taskArgs.sourcechain + "/" + taskArgs.destchain + "/sequences/" + taskArgs.sequence
        let packetRec = await packet.receipts(Buffer.from(key,"utf-8"))
        console.log(packetRec)
    })

task("queryCommit", "Packet")
    .addParam("packet","packet address")
    .addParam("sourcechain","sourceChain")
    .addParam("destchain","sourceChain")
    .addParam("sequence","sourceChain")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)
        let key = "acks/" + taskArgs.sourcechain + "/" + taskArgs.destchain + "/sequences/" + taskArgs.sequence
        let packetRec = await packet.commitments(Buffer.from(key,"utf-8"))
        console.log(packetRec)
    })  

task("queryRole", "Packet")
    .addParam("packet","packet address")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await packetFactory.attach(taskArgs.packet)

        let roleHash =  await packet.MULTISEND_ROLE()
        console.log(roleHash)
    })  
   
module.exports = {}
