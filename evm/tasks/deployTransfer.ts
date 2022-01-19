import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS

task("deployTransfer", "Deploy Transfer")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await hre.upgrades.deployProxy(
            transferFactory,
            [
                String(PACKET_ADDRESS),
                String(CLIENT_MANAGER_ADDRESS),
                String(ACCESS_MANAGER_ADDRESS),
            ],
        )
        await transfer.deployed()
        console.log("Transfer deployed to:", transfer.address.toLocaleLowerCase())
    })

module.exports = {}
