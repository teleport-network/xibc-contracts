import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const CLIENT_MANAGER_ADDRES = process.env.CLIENT_MANAGER_ADDRES

task("deployTssClient", "Deploy Tss Client")
    .setAction(async (taskArgs, hre) => {
        const tssFactory = await hre.ethers.getContractFactory(
            'TssClient'
        )

        const tss = await hre.upgrades.deployProxy(
            tssFactory,
            [String(CLIENT_MANAGER_ADDRES)],
        )
        await tss.deployed()
        console.log("TssClient deployed to:", tss.address)
    })

module.exports = {}
