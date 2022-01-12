import "@nomiclabs/hardhat-web3"
import {task, types} from "hardhat/config"

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
    .addParam("transfer", "transfer contract address")
    .addParam("address", "ERC20 contract address")
    .addParam("receiver", "receiver address")
    .addParam("amount", "transfer amount")
    .addParam("destchain", "dest chain name")
    .addParam("relaychain", "relay chain name", "", types.string, true)
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await transferFactory.attach(taskArgs.transfer)

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
    .addParam("transfer", "transfer contract address")
    .addParam("receiver", "receiver address")
    .addParam("amount", "transfer amount")
    .addParam("destchain", "dest chain name")
    .addParam("relaychain", "relay chain name", "", types.string, true)
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await transferFactory.attach(taskArgs.transfer)

        let transferdata = {
            receiver: taskArgs.receiver,
            destChain: taskArgs.destchain,
            relayChain: taskArgs.relaychain,
        }
        let res = await transfer.sendTransfer(
            transferdata,
            {value: hre.ethers.utils.parseEther(taskArgs.amount)}
        )
        console.log(await res.wait())
    })

task("bindToken", "bind ERC20 token trace")
    .addParam("transfer", "transfer contract address")
    .addParam("address", "ERC20 contract address")
    .addParam("oritoken", "origin token")
    .addParam("orichain", "origin chain")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await transferFactory.attach(taskArgs.transfer)

        let res = await transfer.bindToken(
            taskArgs.address,
            taskArgs.oritoken,
            taskArgs.orichain,
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

task("deployToken", "Deploy Token")
    .addParam("name", "token name")
    .addParam("symbol", "token symbol")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('testToken')
        const token = await tokenFactory.deploy(taskArgs.name, taskArgs.symbol)
        await token.deployed();

        console.log("Token %s deployed to:%s", taskArgs.name, token.address);
        console.log("export ERC20_TOKEN=%s", token.address);

    });

module.exports = {}
