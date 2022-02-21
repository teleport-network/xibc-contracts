import "@nomiclabs/hardhat-web3"
import { task, types } from "hardhat/config"

const TEST_PAYABLE_ADDRESS = process.env.TEST_PAYABLE_ADDRESS

task("deployTestPayable", "Deploy Payable")
    .setAction(async (taskArgs, hre) => {
        const TestPayableFactory = await hre.ethers.getContractFactory('TestPayable')
        const TestPayable = await hre.upgrades.deployProxy(TestPayableFactory)
        await TestPayable.deployed()

        console.log("TestPayable deployed to:", TestPayable.address.toLocaleLowerCase())
        console.log("export TEST_PAYABLE_ADDRESS=%s", TestPayable.address.toLocaleLowerCase())
    })

task("getbalance", "Deploy Payable")
    .setAction(async (taskArgs, hre) => {
        const TestPayableFactory = await hre.ethers.getContractFactory('TestPayable')
        const recv = TestPayableFactory.attach(String(TEST_PAYABLE_ADDRESS))
        const res = await recv.getBalance()
        console.log(res)
    })
module.exports = {}