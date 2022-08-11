import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

const CLIENT_MANAGER_AC_ADDRESS = process.env.CLIENT_MANAGER_AC_ADDRESS
const PACKET_AC_ADDRESS = process.env.PACKET_AC_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS
const ENDPOINT_AC_ADDRESS = process.env.ENDPOINT_AC_ADDRESS
const NOT_PROXY = process.env.NOT_PROXY

task("deployEndpointAC", "Deploy Endpoint")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('EndpointAC')
        if (NOT_PROXY) {
            const endpoint = await endpointFactory.deploy()
            await endpoint.deployed()

            console.log("Endpoint deployed !")
            console.log("export ENDPOINT_AC_ADDRESS=%s", endpoint.address.toLocaleLowerCase())
        } else {
            const endpoint = await hre.upgrades.deployProxy(
                endpointFactory,
                [
                    String(PACKET_AC_ADDRESS),
                    String(ACCESS_MANAGER_ADDRESS),
                ],
            )
            await endpoint.deployed()
            console.log("Endpoint deployed to:", endpoint.address.toLocaleLowerCase())
            console.log("export ENDPOINT_AC_ADDRESS=%s", endpoint.address.toLocaleLowerCase())
            fs.appendFileSync('env.txt', 'export ENDPOINT_AC_ADDRESS=' + endpoint.address.toLocaleLowerCase() + '\n')
        }

    })

task("upgradeEndpoint", "upgrade Endpoint")
    .setAction(async (taskArgs, hre) => {
        const MockEndpointFactory = await hre.ethers.getContractFactory("MockEndpoint");
        const mockEndpointProxy = await hre.upgrades.upgradeProxy(
            String(ENDPOINT_AC_ADDRESS),
            MockEndpointFactory,
            {
                unsafeAllowCustomTypes: true,
            }
        );
        await mockEndpointProxy.setVersion(3)
        console.log(mockEndpointProxy.address)
    })

task("setVersion", "set version for mockEndpoint")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('MockEndpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_AC_ADDRESS))

        await endpoint.setVersion(2)
    })

task("getVersion", "get version for mockEndpoint")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('MockEndpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_AC_ADDRESS))

        console.log(await endpoint.version())
    })

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
    .addParam("tokenaddress", "ERC20 contract address")
    .addParam("receiver", "receiver address")
    .addParam("amount", "transfer amount")
    .addParam("dstchain", "dst chain name")
    .addParam("feeamount", "relay fee token address")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/endpoint/Endpoint.sol:Endpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_AC_ADDRESS))

        let crossChainData = {
            dstChain: taskArgs.dstchain,
            tokenAddress: taskArgs.tokenaddress,
            receiver: taskArgs.receiver,
            amount: taskArgs.amount,
            contractAddress: "0x0000000000000000000000000000000000000000",
            callData: Buffer.from("", "utf-8"),
            callbackAddress: "0x0000000000000000000000000000000000000000",
            feeOption: 0,
        }

        let fee = {
            tokenAddress: taskArgs.tokenaddress,
            amount: taskArgs.feeamount,
        }

        let baseToken = hre.ethers.utils.parseEther("0")
        if (crossChainData.tokenAddress == "0x0000000000000000000000000000000000000000") {
            baseToken = baseToken.add(hre.ethers.utils.parseEther(crossChainData.amount))
        }

        if (fee.tokenAddress == "0x0000000000000000000000000000000000000000") {
            baseToken = baseToken.add(hre.ethers.utils.parseEther(fee.amount))
        }

        crossChainData.amount = hre.ethers.utils.parseEther(crossChainData.amount)
        console.log(crossChainData.amount)
        if (baseToken.gt(hre.ethers.utils.parseEther("0"))) {
            let res = await endpoint.crossChainCall(
                crossChainData,
                fee,
                { value: baseToken }
            )
            console.log(await res.wait())
        } else {
            let res = await endpoint.crossChainCall(
                crossChainData,
                fee
            )
            console.log(await res.wait())
        }
    })

task("bindToken", "bind ERC20 token trace")
    .addParam("token", "ERC20 contract address")
    .addParam("oritoken", "origin token")
    .addParam("orichain", "origin chain")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/endpoint/Endpoint.sol:Endpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_AC_ADDRESS))

        let res = await endpoint.bindToken(
            taskArgs.token,
            taskArgs.oritoken,
            taskArgs.orichain,
        )
        console.log(await res.wait())
    })

task("queryBindings", "query ERC20 token trace")
    .addParam("token", "ERC20 contract address")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/endpoint/Endpoint.sol:Endpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_AC_ADDRESS))

        let res = await endpoint.bindings(taskArgs.token)
        console.log(await res)
    })

task("queryBindingsL", "query ERC20 token trace")
    .addParam("token", "ERC20 contract address")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('contracts/chains/01-teleport/core/endpoint/Endpoint.sol:Endpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_AC_ADDRESS))

        let res = await endpoint.bindings(taskArgs.token)
        console.log(await res)
    })

task("queryOutToken", "Query out token")
    .addParam("token", "token address ")
    .addParam("chainname", "chainName")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/endpoint/Endpoint.sol:Endpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_AC_ADDRESS))

        let outToken = (await endpoint.outTokens(taskArgs.token, taskArgs.chainname))
        console.log(outToken)
    });

task("queryTrace", "Query trace")
    .addParam("orichain", "srcchain name")
    .addParam("token", "token address")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/endpoint/Endpoint.sol:Endpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_AC_ADDRESS))

        let trace = await endpoint.bindingTraces(taskArgs.orichain + "/" + taskArgs.token)
        console.log(trace)
    });

module.exports = {}
