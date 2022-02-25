import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const ROUTING_ADDRESS = process.env.ROUTING_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS

task("deployRouting", "Deploy Routing")
    .setAction(async (taskArgs, hre) => {
        const routingFactory = await hre.ethers.getContractFactory('Routing')
        const routing = await hre.upgrades.deployProxy(routingFactory, [String(ACCESS_MANAGER_ADDRESS)])
        await routing.deployed()
        console.log("Routing deployed to:", routing.address.toLocaleLowerCase())
        console.log("export ROUTING_ADDRESS=%s", routing.address.toLocaleLowerCase())
    })

task("addRouting", "Add module routing")
    .addParam("module", "module name")
    .addParam("address", "module address")
    .setAction(async (taskArgs, hre) => {
        const routingFactory = await hre.ethers.getContractFactory('Routing')
        const routing = await routingFactory.attach(String(ROUTING_ADDRESS))
        const result = await routing.addRouting(taskArgs.module, taskArgs.address)
        console.log(result)
    })

task("getModule", "Get module routing")
    .addParam("module", "module name")
    .setAction(async (taskArgs, hre) => {
        const routingFactory = await hre.ethers.getContractFactory('Routing')
        const routing = await routingFactory.attach(String(ROUTING_ADDRESS))
        const result = await routing.getModule(taskArgs.module)
        console.log(result)
    })

module.exports = {}
