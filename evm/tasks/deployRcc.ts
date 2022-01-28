import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const ROUTING_ADDRESS = process.env.ROUTING_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS

task("deployRcc", "Deploy MultiCall")
    .setAction(async (taskArgs, hre) => {
        const RCCFactory = await hre.ethers.getContractFactory('RCC')
        const rcc = await hre.upgrades.deployProxy(
            RCCFactory,
            [
                String(CLIENT_MANAGER_ADDRESS),
                String(ROUTING_ADDRESS),
                String(ACCESS_MANAGER_ADDRESS)
            ]
        )
        await rcc.deployed()

        console.log("Rcc deployed to:", rcc.address.toLocaleLowerCase())
        console.log("export RCC_ADDRESS=%s", rcc.address.toLocaleLowerCase())
    })
module.exports = {}