import "@nomiclabs/hardhat-web3"
import { task, types } from "hardhat/config"
import fs = require('fs');

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const MULTICALl_ADDRESS = process.env.MULTICALl_ADDRESS
const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const TRANSFER_ADDRESS = process.env.TRANSFER_ADDRESS
const PROXY_ADDRESS = process.env.PROXY_ADDRESS

task("deployProxy", "Deploy Proxy")
    .setAction(async (taskArgs, hre) => {
        const ProxyFactory = await hre.ethers.getContractFactory('Proxy')
        const proxy = await hre.upgrades.deployProxy(
            ProxyFactory,
            [
                String(CLIENT_MANAGER_ADDRESS),
                String(MULTICALl_ADDRESS),
                String(PACKET_ADDRESS),
                String(TRANSFER_ADDRESS)
            ]
        )
        await proxy.deployed()

        console.log("Proxy deployed to:", proxy.address.toLocaleLowerCase())
        console.log("export PROXY_ADDRESS=%s", proxy.address.toLocaleLowerCase())
        fs.appendFileSync('env.txt', 'export PROXY_ADDRESS='+proxy.address.toLocaleLowerCase()+'\n')
    })

task("send", "Send Proxy")
    .addParam("proxy", "proxy address")
    .addParam("destchain", "destChain name")
    .addParam("erctokenaddress", "tokenAddress for erc20 transfer")
    .addParam("amount", "amount for erc20 transfer and rcc transfer")
    .addParam("rcctokenaddress", "tokenAddress for rcc transfer")
    .addParam("rccreceiver", "receiver for rcc transfer")
    .addParam("rccdestchain", "destchain for rcc transfer")
    .addParam("rccrelaychain", "relay chain name", "", types.string, true)
    .setAction(async (taskArgs, hre) => {
        const ProxyFactory = await hre.ethers.getContractFactory('Proxy')
        const proxy = await ProxyFactory.attach(taskArgs.proxy)
        // teleport.agent 0x0000000000000000000000000000000010000007
        let ERC20TransferData = {
            tokenAddress: taskArgs.erctokenaddress.toLocaleLowerCase(),
            receiver: "0x0000000000000000000000000000000010000007",
            amount: taskArgs.amount,
        }
        let rccTransfer = {
            tokenAddress: taskArgs.rcctokenaddress.toLocaleLowerCase(),
            receiver: taskArgs.rccreceiver.toLocaleLowerCase(),
            amount: taskArgs.amount,
            destChain: taskArgs.rccdestchain,
            relayChain: taskArgs.rccrelaychain,
        }
        if (ERC20TransferData.tokenAddress == "0x0000000000000000000000000000000000000000") {
            console.log("transfer base")
            let res = await proxy.send(taskArgs.destchain, ERC20TransferData, ERC20TransferData.receiver, rccTransfer, { value: taskArgs.amount })
            console.log(res)
        } else {
            console.log("transfer erc20")
            let res = await proxy.send(taskArgs.destchain, ERC20TransferData, ERC20TransferData.receiver, rccTransfer)
            console.log(res)
        }

    })
module.exports = {}