import "@nomiclabs/hardhat-web3"
import { task,types } from "hardhat/config"

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const MULTICALl_ADDRESS = process.env.MULTICALl_ADDRESS
const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const TRANSFER_ADDRESS = process.env.TRANSFER_ADDRESS

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
    })

task("send", "Send Proxy")
    .addParam("proxy", "proxy address")
    .addParam("destchain", "destChain name")
    .addParam("erctokenaddress","tokenAddress for erc20 transfer")
    .addParam("ercreceiver","receiver for erc20 transfer, must be agent contract address")
    .addParam("amount","amount for erc20 transfer and rcc transfer")
    .addParam("rcctokenaddress","tokenAddress for rcc transfer")
    .addParam("rccreceiver","receiver for rcc transfer")
    .addParam("rccdestchain","destchain for rcc transfer")
    .addParam("rccrelaychain", "relay chain name", "", types.string, true)
    .setAction(async (taskArgs, hre) => {
        const ProxyFactory = await hre.ethers.getContractFactory('Proxy')
        const proxy = await ProxyFactory.attach(taskArgs.proxy)
        // teleport.agent 0x0000000000000000000000000000000010000007
        let ERC20TransferData = {
            tokenAddress: taskArgs.erctokenaddress.toLocaleLowerCase(),
            receiver: taskArgs.ercreceiver.toLocaleLowerCase(),
            amount: taskArgs.amount,
        }
        let rccTransfer = {
            tokenAddress:taskArgs.rcctokenaddress.toLocaleLowerCase(),
            receiver: taskArgs.rccreceiver.toLocaleLowerCase(),
            amount: taskArgs.amount,
            destChain: taskArgs.rccdestchain,
            relayChain: taskArgs.rccrelaychain,
        }

        await proxy.send(taskArgs.destchain, ERC20TransferData, ERC20TransferData.receiver, rccTransfer)
    })
module.exports = {}