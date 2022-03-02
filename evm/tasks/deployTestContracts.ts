import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

task("deployRecl", "Deploy Recl")
    .setAction(async (taskArgs, hre) => {
        const TestReclFactory = await hre.ethers.getContractFactory('TestRecl')
        const recl = await TestReclFactory.deploy()

        console.log("Recl deployed to:", recl.address.toLocaleLowerCase())
        console.log("export RECL_ADDRESS=%s", recl.address.toLocaleLowerCase())
    })

task("deployPayable", "Deploy payable")
    .setAction(async (taskArgs, hre) => {
        const TestPayableFactory = await hre.ethers.getContractFactory('TestPayable')
        const payable = await TestPayableFactory.deploy()

        console.log("PAYABLE deployed to:", payable.address.toLocaleLowerCase())
        console.log("export PAYABLE_ADDRESS=%s", payable.address.toLocaleLowerCase())
    })
module.exports = {}