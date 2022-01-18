import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

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

module.exports = {}
