import "@nomiclabs/hardhat-web3"
import { ethers } from "hardhat"
import { task, types } from "hardhat/config"

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


task("transferToken", "Transfer token")
    .addParam("transfer", "transfer contract address")
    .addParam("address", "ERC20 contract address")
    .addParam("receiver", "receiver address")
    .addParam("amount", "transfer amount")
    .addParam("destchain", "dest chain name")
    .addParam("relaychain", "relay chain name", "", types.string, true)
    .addParam("relayfeeaddress", "relay fee token address")
    .addParam("relayfeeamout", "relay fee amout")
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

        let fee = {
            tokenAddress: taskArgs.relayfeeaddress,
            amount: taskArgs.relayfeeamout,
        }

        let baseToken = hre.ethers.utils.parseEther("0")
        if (transferdata.tokenAddress == "0x0000000000000000000000000000000000000000") {
            baseToken = baseToken.add(hre.ethers.utils.parseEther(transferdata.amount))
        }

        if (fee.tokenAddress == "0x0000000000000000000000000000000000000000") {
            baseToken = baseToken.add(hre.ethers.utils.parseEther(fee.amount))
        }

        if (baseToken.gt(hre.ethers.utils.parseEther("0"))) {
            let res = await transfer.sendTransfer(
                transferdata,
                fee,
                { value: baseToken }
            )
            console.log(await res.wait())
        } else {
            let res = await transfer.sendTransfer(
                transferdata,
                fee
            )
            console.log(await res.wait())
        }
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

        console.log("Token %s deployed to:%s", taskArgs.name, token.address.toLocaleLowerCase());
        console.log("export ERC20_TOKEN=%s", token.address.toLocaleLowerCase());

    });

task("mintToken", "Mint Token")
    .addParam("address", "token address")
    .addParam("to", "reciver")
    .addParam("amount", "token mint amount")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('testToken')
        const token = await tokenFactory.attach(taskArgs.address)

        await token.mint(taskArgs.to, taskArgs.amount)
    });

task("queryErc20balances", "Query ERC20 balances")
    .addParam("address", "token address")
    .addParam("user", "user address ")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('testToken')
        const token = await tokenFactory.attach(taskArgs.address)

        let balances = (await token.balanceOf(taskArgs.user)).toString()
        console.log(balances)
    });

task("approve", "approve ERC20 token to others")
    .addParam("address", "erc20 address")
    .addParam("transfer", "transfer address ")
    .addParam("amount", "approve amount")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('testToken')
        const token = await tokenFactory.attach(taskArgs.address)

        let res = await token.approve(taskArgs.transfer, taskArgs.amount)
        console.log(res)
    });

task("queryAllowance", "Query ERC20 allowance")
    .addParam("address", "erc20 address")
    .addParam("transfer", "transfer address ")
    .addParam("account", "account address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('testToken')
        const token = await tokenFactory.attach(taskArgs.address)

        let allowances = (await token.allowance(taskArgs.account, taskArgs.transfer))
        console.log(allowances)
    });

task("queryOutToken", "Query out token")
    .addParam("transfer", "transfer address ")
    .addParam("token", "token address ")
    .addParam("chainname", "chainName")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await transferFactory.attach(taskArgs.transfer)

        let outToken = (await transfer.outTokens(taskArgs.token, taskArgs.chainname))
        console.log(outToken)
    });

task("queryTrace", "Query trace")
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
