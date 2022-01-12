import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const CLIENT_MANAGER_ADDRES = process.env.CLIENT_MANAGER_ADDRES
const PACKET_ADDRES = process.env.PACKET_ADDRES
const ACCESS_MANAGER_ADDRES = process.env.ACCESS_MANAGER_ADDRES

task("deployTransfer", "Deploy Transfer")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await hre.upgrades.deployProxy(
            transferFactory,
            [
                String(PACKET_ADDRES),
                String(CLIENT_MANAGER_ADDRES),
                String(ACCESS_MANAGER_ADDRES),
            ],
        )
        await transfer.deployed()
        console.log("Transfer deployed to:", transfer.address)
    })

module.exports = {}
