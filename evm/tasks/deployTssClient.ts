import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS

task("deployTssClient", "Deploy Tss Client")
    .setAction(async (taskArgs, hre) => {
        const tssFactory = await hre.ethers.getContractFactory(
            'TssClient'
        )
        const tss = await hre.upgrades.deployProxy(
            tssFactory,
            [String(CLIENT_MANAGER_ADDRESS)],
        )
        await tss.deployed()
        console.log("TssClient deployed to:", tss.address.toLocaleLowerCase())
        console.log("export TSS_CLIENT=%s", tss.address.toLocaleLowerCase())
        fs.appendFileSync('env.txt', 'export TSS_CLIENT='+tss.address.toLocaleLowerCase()+'\n')
    })

module.exports = {}
