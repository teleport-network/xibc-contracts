import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import { keccak256 } from "ethers/lib/utils"
import fs = require('fs');

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
        fs.appendFileSync('env.txt', 'export ACCESS_MANAGER_ADDRESS='+accessManager.address.toLocaleLowerCase()+'\n')
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
        fs.appendFileSync('env.txt', '# grantRole tx hash: '+result.hash+'\n')
    })

task("revokeRole", "revoke Role")
    .addParam("role", "revoke Role")
    .addParam("to", "revoke Role to contract")
    .setAction(async (taskArgs, hre) => {
        const accessManagerFactory = await hre.ethers.getContractFactory('AccessManager')
        const accessManager = await accessManagerFactory.attach(String(ACCESS_MANAGER_ADDRESS))
        let role = Buffer.from(taskArgs.role, "utf-8")
        const result = await accessManager.revokeRole(keccak256(role), taskArgs.to)
        console.log(result)
    })

task("batchGrantRole", "batch grant Role")
  .addParam("roles", "batch grant Roles")
  .addParam("tos", "batch grant Role to contracts")
  .setAction(async (taskArgs, hre) => {
    const accessManagerFactory = await hre.ethers.getContractFactory('AccessManager')
    const accessManager = await accessManagerFactory.attach(String(ACCESS_MANAGER_ADDRESS))

    let rs= new Array();
    let roles = taskArgs.roles.split(",")
    for(let i=0; i<roles.length; i++){
      rs.push(keccak256(Buffer.from(roles[i], "utf-8")))
    }
    const result = await accessManager.batchGrantRole(rs, taskArgs.tos.split(","))
    console.log(result)
})

task("batchRevokeRole", "batch revoke Role")
  .addParam("roles", "batch revoke Roles")
  .addParam("tos", "batch revoke Role to contracts")
  .setAction(async (taskArgs, hre) => {
    const accessManagerFactory = await hre.ethers.getContractFactory('AccessManager')
    const accessManager = await accessManagerFactory.attach(String(ACCESS_MANAGER_ADDRESS))

    let rs= new Array();
    let roles = taskArgs.roles.split(",")
    for(let i=0; i<roles.length; i++){
      rs.push(keccak256(Buffer.from(roles[i], "utf-8")))
    }
    const result = await accessManager.batchRevokeRole(rs, taskArgs.tos.split(","))
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
        fs.appendFileSync('env.txt', '#hasRole result: '+result+'\n')
    })

module.exports = {}
