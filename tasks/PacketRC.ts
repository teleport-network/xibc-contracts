import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

const CLIENT_MANAGER_RC_ADDRESS = process.env.CLIENT_MANAGER_RC_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS
const NOT_PROXY = process.env.NOT_PROXY

task("deployPacketRC", "Deploy Packet")
    .addParam("chain", "chain name")
    .setAction(async (taskArgs, hre) => {
        const packetFactory = await hre.ethers.getContractFactory('PacketRC')
        if (NOT_PROXY) {
            const packet = await packetFactory.deploy()
            await packet.deployed()
            console.log("Packet deployed  !")
            console.log("export PACKET_RC_ADDRESS=%s", packet.address.toLocaleLowerCase())
        } else {
            const packet = await hre.upgrades.deployProxy(
                packetFactory,
                [
                    taskArgs.chain,
                    String(CLIENT_MANAGER_RC_ADDRESS),
                    String(ACCESS_MANAGER_ADDRESS)
                ]
            )
            await packet.deployed()
            console.log("Packet deployed to:", packet.address.toLocaleLowerCase())
            console.log("export PACKET_RC_ADDRESS=%s", packet.address.toLocaleLowerCase())
            fs.appendFileSync('env.txt', 'export PACKET_RC_ADDRESS=' + packet.address.toLocaleLowerCase() + '\n')
        }
    })

module.exports = {}