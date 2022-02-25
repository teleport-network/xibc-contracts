import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import { keccak256 } from "ethers/lib/utils"

const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS
task("deployAcessManager", "Deploy acessManager")
    .addParam("wallet", "multi sign address")
    .setAction(async (taskArgs, hre) => {
        const accessManagerFactory = await hre.ethers.getContractFactory('AccessManager')
        const accessManager = await hre.upgrades.deployProxy(
            accessManagerFactory,
            [taskArgs.wallet]
        )
        await accessManager.deployed()
        console.log("AccessManager deployed to:", accessManager.address.toLocaleLowerCase())
        console.log("export ACCESS_MANAGER_ADDRESS=%s", accessManager.address.toLocaleLowerCase())
    })

task("grantRole", "grant Role")
    .addParam("role", "grant Role")
    .addParam("to", "grant Role to contract")
    .setAction(async (taskArgs, hre) => {
        const accessManagerFactory = await hre.ethers.getContractFactory('AccessManager')
        const accessManager = await accessManagerFactory.attach(String(ACCESS_MANAGER_ADDRESS))
        let role = Buffer.from(taskArgs.role, "utf-8")
        const result = await accessManager.grantRole(keccak256(role), taskArgs.to)
        console.log(result)
    })

task("roleBytes", "get role bytes")
    .addParam("role", "grant Role")
    .setAction(async (taskArgs, hre) => {
        let role = Buffer.from(taskArgs.role, "utf-8")
        console.log(keccak256(role))
    })

task("hasRole", "check address has Role")
    .addParam("role", "grant Role")
    .addParam("to", "grant Role to contract")
    .setAction(async (taskArgs, hre) => {
        const accessManagerFactory = await hre.ethers.getContractFactory('AccessManager')
        const accessManager = await accessManagerFactory.attach(String(ACCESS_MANAGER_ADDRESS),)
        let role = Buffer.from(taskArgs.role, "utf-8")
        const result = await accessManager.hasRole(keccak256(role), taskArgs.to)
        console.log(result)
    })

module.exports = {}