import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const crossChainContractAddress = "0x0000000000000000000000000000000020000002"

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

task("crossChain", "Cross chain call")
    .addParam("destchain", "dest chain name")
    .addParam("token", "ERC20 contract address")
    .addParam("receiver", "receiver address")
    .addParam("amount", "transfer amount")
    .addParam("contract", "contract call address")
    .addParam("calldata", "contract call data")
    .addParam("callback", "callback address")
    .addParam("feetoken", "relay fee token address")
    .addParam("feeamout", "relay fee amout")
    .setAction(async (taskArgs, hre) => {
        const crossChainFactory = await hre.ethers.getContractFactory('CrossChain')
        const crossChain = await crossChainFactory.attach(crossChainContractAddress)

        let crossChainData = {
            destChain: taskArgs.destchain,
            relayChain: "",
            tokenAddress: taskArgs.tokenaddress,
            receiver: taskArgs.receiver,
            amount: taskArgs.amount,
            contractAddress: taskArgs.contract,
            callData: taskArgs.calldata,
            callbackAddress: taskArgs.callback,
            feeOption: taskArgs.feeoption,
        }

        let fee = {
            tokenAddress: taskArgs.feetoken,
            amount: taskArgs.feeamout,
        }

        let res = await crossChain.crossChainCall(crossChainData, fee)
        console.log(await res.wait())
    })

task("queryBindings", "query ERC20 token trace")
    .addParam("address", "ERC20 contract address")
    .setAction(async (taskArgs, hre) => {
        const crossChainFactory = await hre.ethers.getContractFactory('CrossChain')
        const crossChain = await crossChainFactory.attach(crossChainContractAddress)

        let res = await crossChain.bindings(taskArgs.address)
        console.log(await res)
    })


task("queryTrace", "Token")
    .addParam("srcchain", "srcchain name")
    .addParam("token", "token address")
    .setAction(async (taskArgs, hre) => {
        const crossChainFactory = await hre.ethers.getContractFactory('CrossChain')
        const crossChain = await crossChainFactory.attach(crossChainContractAddress)

        let trace = await crossChain.bindingTraces(taskArgs.srcchain + "/" + taskArgs.token)
        console.log(trace)
    });

module.exports = {}