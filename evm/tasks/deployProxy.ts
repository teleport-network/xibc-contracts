import "@nomiclabs/hardhat-web3"
import { task, types } from "hardhat/config"
import fs = require('fs');

const PROXY_ADDRESS = process.env.PROXY_ADDRESS
const ENDPOINT_ADDRESS = process.env.ENDPOINT_ADDRESS


task("deployProxy", "Deploy Proxy")
    .addParam("relaychain","relay chain name")
    .setAction(async (taskArgs, hre) => {
        const ProxyFactory = await hre.ethers.getContractFactory('Proxy')
        const proxy = await hre.upgrades.deployProxy(
            ProxyFactory,
            [
                taskArgs.relaychain,
            ]
        )
        await proxy.deployed()

        console.log("Proxy deployed to:", proxy.address.toLocaleLowerCase())
        console.log("export PROXY_ADDRESS=%s", proxy.address.toLocaleLowerCase())
        fs.appendFileSync('env.txt', 'export PROXY_ADDRESS=' + proxy.address.toLocaleLowerCase() + '\n')
    })

task("send", "Send Proxy")
    .addParam("refunder", "refunder address")
    .addParam("dstchain", "dstChain name")
    .addParam("tokenaddress", "tokenAddress for erc20 transfer")
    .addParam("amount", "amount for erc20 transfer and rcc transfer")
    .addParam("receiver", "receiver for rcc transfer")
    .addParam("callback","callback address")
    .addParam("feeamount", "relay fee")
    .addParam("feeoption","feeOption")
    .setAction(async (taskArgs, hre) => {
        const ProxyFactory = await hre.ethers.getContractFactory('Proxy')
        const proxy = await ProxyFactory.attach(String(PROXY_ADDRESS))
        // teleport.agent 0x0000000000000000000000000000000040000001
        let AgentData = {
            refundAddress:taskArgs.refunder,
            dstChain:taskArgs.dstchain,
            tokenAddress : taskArgs.tokenaddress,
            amount: taskArgs.amount,
            feeAmount: taskArgs.feeamount,
            receiver : taskArgs.receiver,
            callbackAddress : taskArgs.callback,
            feeOption : taskArgs.feeoption,
        }

        let agentData = await proxy.genCrossChainData(AgentData)
        console.log("agentData:", agentData)

        let fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }

        const endpointFactory = await hre.ethers.getContractFactory('Endpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_ADDRESS))
        // 2-Hop has no fee at the first packet
        let res = await endpoint.crossChainCall(agentData, fee, { value: taskArgs.amount })
        console.log(res)
    })

module.exports = {}