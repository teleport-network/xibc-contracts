import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const TRANSFER_ADDRES = process.env.TRANSFER_ADDRES
const RCC_ADDRESS = process.env.RCC_ADDRESS

task("deployMultiCall", "Deploy MultiCall")
    .setAction(async (taskArgs, hre) => {
        const multiCallFactory = await hre.ethers.getContractFactory('MultiCall')
        const multiCall = await hre.upgrades.deployProxy(
            multiCallFactory,
            [
                String(PACKET_ADDRESS),
                String(CLIENT_MANAGER_ADDRESS),
                String(TRANSFER_ADDRES),
                String(RCC_ADDRESS)
            ]
        )
        await multiCall.deployed()
        console.log("Packet deployed to:", multiCall.address.toLocaleLowerCase())
        console.log("export MULTICALl_ADDRESS=%s", multiCall.address.toLocaleLowerCase())
    })

module.exports = {}