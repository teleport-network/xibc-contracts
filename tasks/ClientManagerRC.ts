import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import { utils } from "ethers"
import { readFileSync } from 'fs'
import fs = require('fs');

const CLIENT_MANAGER_RC_ADDRESS = process.env.CLIENT_MANAGER_RC_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS

task("deployClientManagerRC", "Deploy Client Manager")
    .setAction(async (taskArgs, hre) => {
        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManagerRC')
        const clientManager = await hre.upgrades.deployProxy(
            clientManagerFactory,
            [
                String(ACCESS_MANAGER_ADDRESS),
            ]
        )
        await clientManager.deployed()
        console.log("Client Manager deployed to:", clientManager.address.toLocaleLowerCase())
        console.log("export CLIENT_MANAGER_RC_ADDRESS=%s", clientManager.address.toLocaleLowerCase())
        fs.appendFileSync('env.txt', 'export CLIENT_MANAGER_RC_ADDRESS=' + clientManager.address.toLocaleLowerCase() + '\n')
    })

module.exports = {}
