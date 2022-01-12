import "@nomiclabs/hardhat-web3"
import { task, types } from "hardhat/config"

const transferContractAddress = "0x0000000000000000000000000000000010000003"

task("queryBalance", "Query Balance")
    .addParam("privkey", "private key")
    .setAction(async (taskArgs, hre) => {
        const provider = new hre.ethers.providers.JsonRpcProvider(taskArgs.node)

        let privateKey = taskArgs.privkey
        let wallet = new hre.ethers.Wallet(privateKey)

        wallet = wallet.connect(provider)
        let nonce = await wallet.getTransactionCount()
        console.log("nonce: ", nonce)
        let balance = await wallet.getBalance()
        console.log("balance: ", balance.toString())
    })


task("transferERC20", "Sender ERC20 Token")
    .addParam("address", "ERC20 contract address")
    .addParam("receiver", "receiver address")
    .addParam("amount", "transfer amount")
    .addParam("destchain", "dest chain name")
    .addParam("relaychain", "relay chain name", "", types.string, true)
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await transferFactory.attach(transferContractAddress)

        let transferdata = {
            tokenAddress: taskArgs.address,
            receiver: taskArgs.receiver,
            amount: taskArgs.amount,
            destChain: taskArgs.destchain,
            relayChain: taskArgs.relaychain,
        }
        let res = await transfer.sendTransfer(transferdata)
        console.log(await res.wait())
    })


task("transferBase", "Sender Base token")
    .addParam("receiver", "receiver address")
    .addParam("amount", "transfer amount")
    .addParam("destchain", "dest chain name")
    .addParam("relaychain", "relay chain name", "", types.string, true)
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await transferFactory.attach(transferContractAddress)

        let transferdata = {
            receiver: taskArgs.receiver,
            destChain: taskArgs.destchain,
            relayChain: taskArgs.relaychain,
        }
        let res = await transfer.sendTransferBase(
            transferdata,
            { value: hre.ethers.utils.parseEther(taskArgs.amount) }
        )
        console.log(await res.wait())
    })

module.exports = {}