import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const ROUTING_ADDRES = process.env.ROUTING_ADDRES
const ACCESS_MANAGER_ADDRES = process.env.ACCESS_MANAGER_ADDRES

task("deployRouting", "Deploy Routing")
    .setAction(async (taskArgs, hre) => {
        const routingFactory = await hre.ethers.getContractFactory('Routing')
        const routing = await hre.upgrades.deployProxy(routingFactory, [String(ACCESS_MANAGER_ADDRES)])
        await routing.deployed()
        console.log("Routing deployed to:", routing.address)
        console.log("export ROUTING_ADDRES=%s", routing.address)
    })

task("addRouting", "Add module routing")
    .addParam("module", "module name")
    .addParam("address", "module address")
    .setAction(async (taskArgs, hre) => {
        const routingFactory = await hre.ethers.getContractFactory('Routing')
        const routing = await routingFactory.attach(String(ROUTING_ADDRES))
        const result = await routing.addRouting(taskArgs.module, taskArgs.address)
        console.log(result)
    })

module.exports = {}
