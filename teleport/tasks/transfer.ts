import "@nomiclabs/hardhat-web3"
import { task, types } from "hardhat/config"

const transferContractAddress = "0x0000000000000000000000000000000030000001"

task("queryBalance", "Query Balance")
    .addParam("privkey", "private key")
    .addParam("node", "node url")
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
        let res = await transfer.sendTransferERC20(transferdata)
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

task("queryBindings", "query ERC20 token trace")
    .addParam("transfer", "transfer contract address")
    .addParam("address", "ERC20 contract address")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await transferFactory.attach(taskArgs.transfer)

        let res = await transfer.bindings(taskArgs.address)
        console.log(await res)
    })


task("queryTrace", "Token")
    .addParam("transfer", "transfer address")
    .addParam("srcchain", "srcchain name")
    .addParam("token", "token address")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await transferFactory.attach(taskArgs.transfer)

        let trace = await transfer.bindingTraces(taskArgs.srcchain + "/" + taskArgs.token)
        console.log(trace)
    });
module.exports = {}