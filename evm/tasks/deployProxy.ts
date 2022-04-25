import "@nomiclabs/hardhat-web3"
import { task, types } from "hardhat/config"
import fs = require('fs');

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const MULTICALl_ADDRESS = process.env.MULTICALl_ADDRESS
const NOT_PROXY = process.env.NOT_PROXY


task("deployProxy", "Deploy Proxy")
    .setAction(async (taskArgs, hre) => {
        const ProxyFactory = await hre.ethers.getContractFactory('Proxy')
        if (NOT_PROXY) {
            const proxy = await ProxyFactory.deploy()
            await proxy.deployed()

            console.log("Proxy deployed  !")
            console.log("export PROXY_ADDRESS=%s", proxy.address.toLocaleLowerCase())
        } else {
            const proxy = await hre.upgrades.deployProxy(
                ProxyFactory,
                [
                    String(CLIENT_MANAGER_ADDRESS),
                    String(PACKET_ADDRESS)
                ]
            )
            await proxy.deployed()

            console.log("Proxy deployed to:", proxy.address.toLocaleLowerCase())
            console.log("export PROXY_ADDRESS=%s", proxy.address.toLocaleLowerCase())
            fs.appendFileSync('env.txt', 'export PROXY_ADDRESS=' + proxy.address.toLocaleLowerCase() + '\n')
        }

    })

task("send", "Send Proxy")
    .addParam("proxy", "proxy address")
    .addParam("refunder", "refunder address")
    .addParam("destchain", "destChain name")
    .addParam("erctokenaddress", "tokenAddress for erc20 transfer")
    .addParam("transferamount", "amount for erc20 transfer and rcc transfer")
    .addParam("rccamount", "amount for erc20 transfer and rcc transfer")
    .addParam("rcctokenaddress", "tokenAddress for rcc transfer")
    .addParam("rccreceiver", "receiver for rcc transfer")
    .addParam("rccdestchain", "destchain for rcc transfer")
    .addParam("rccrelaychain", "relay chain name", "", types.string, true)
    .addParam("feeAmount", "relay fee")
    .setAction(async (taskArgs, hre) => {
        const ProxyFactory = await hre.ethers.getContractFactory('Proxy')
        const proxy = await ProxyFactory.attach(taskArgs.proxy)
        // teleport.agent 0x0000000000000000000000000000000040000001
        let ERC20TransferData = {
            tokenAddress: taskArgs.erctokenaddress.toLocaleLowerCase(),
            receiver: "0x0000000000000000000000000000000040000001",
            amount: taskArgs.transferamount,
        }
        let rccTransfer = {
            tokenAddress: taskArgs.rcctokenaddress.toLocaleLowerCase(),
            receiver: taskArgs.rccreceiver.toLocaleLowerCase(),
            amount: taskArgs.rccamount,
            destChain: taskArgs.rccdestchain,
            relayChain: taskArgs.rccrelaychain,
        }

        let multicallData = await proxy.send(taskArgs.refunder, taskArgs.destchain, ERC20TransferData, rccTransfer, taskArgs.feeAmount)
        console.log("multicallData:", multicallData)

        let fee = {
            tokenAddress: taskArgs.erctokenaddress,
            amount: taskArgs.feeAmount,
        }

        const multiCallFactory = await hre.ethers.getContractFactory('MultiCall')
        const multiCall = await multiCallFactory.attach(String(MULTICALl_ADDRESS))
        if (ERC20TransferData.tokenAddress == "0x0000000000000000000000000000000000000000") {
            console.log("transfer base")
            let res = await multiCall.multiCall(multicallData[0], fee, { value: taskArgs.amount })
            console.log(res)
        } else {
            console.log("transfer erc20")
            let res = await multiCall.multiCall(multicallData[0], fee)
            console.log(res)
        }
    })

module.exports = {}