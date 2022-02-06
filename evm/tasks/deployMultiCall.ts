import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import { BigNumber, utils } from "ethers"

const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const TRANSFER_ADDRESS = process.env.TRANSFER_ADDRESS
const RCC_ADDRESS = process.env.RCC_ADDRESS

task("deployMultiCall", "Deploy MultiCall")
    .setAction(async (taskArgs, hre) => {
        const multiCallFactory = await hre.ethers.getContractFactory('MultiCall')
        const multiCall = await hre.upgrades.deployProxy(
            multiCallFactory,
            [
                String(PACKET_ADDRESS),
                String(CLIENT_MANAGER_ADDRESS),
                String(TRANSFER_ADDRESS),
                String(RCC_ADDRESS)
            ]
        )
        await multiCall.deployed()
        console.log("Packet deployed to:", multiCall.address.toLocaleLowerCase())
        console.log("export MULTICALl_ADDRESS=%s", multiCall.address.toLocaleLowerCase())
    })


task("multiCallRcc", "Send MultiCall")
.setAction(async (taskArgs, hre) => {
    const multiCallFactory = await hre.ethers.getContractFactory('MultiCall')
    const multiCall = await multiCallFactory.attach("0xb628aa11d7ba62af1386be90cde6c0eb9d731625")
    // eth.0xe127bd251ab5a499e57034644ef41726c931b45b => teleport.0xd9a41dbe13386c6674d871021106266ea7b27f5c
    let ERC20TransferData = {
        tokenAddress: "0xe127bd251ab5a499e57034644ef41726c931b45b",
        receiver: "0x0000000000000000000000000000000010000007",
        amount: 1,
    }
    let ERC20TransferDataAbi = utils.defaultAbiCoder.encode(["tuple(address,string,uint256)"], [[ERC20TransferData.tokenAddress, ERC20TransferData.receiver, ERC20TransferData.amount]]);

    // teleport.0xd9a41dbe13386c6674d871021106266ea7b27f5c => bsc.0xe9a6bd7ca0fcbe36c2d003872284bbcd47fda8b0
    let dataByte = Buffer.from("efb509250000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d9a41dbe13386c6674d871021106266ea7b27f5c00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000002a307865396136626437636130666362653336633264303033383732323834626263643437666461386230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008746573742d6273630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "hex")
    let RCCData = {
        contractAddress: "0x0000000000000000000000000000000010000007",
        data: dataByte,
    }
    let RCCDataAbi = utils.defaultAbiCoder.encode(["tuple(string,bytes)"], [[RCCData.contractAddress, RCCData.data]]);

    let MultiCallData = {
        destChain: "teleport",
        relayChain: "",
        functions: [BigNumber.from(2)],
        data: [RCCDataAbi],
    }

    // need aprove to transfer on eth 
    // yarn hardhat approve --address 0xe127bd251ab5a499e57034644ef41726c931b45b --transfer 0x2302fEe0A495665Bf0d7094F8044553C01376cd4 --amount 1 --network rinkeby

    let res = await multiCall.multiCall(MultiCallData)
    console.log(res)
})

task("sendmultiCalleth", "Send MultiCall")
.addParam("multicall","multicall address")
    .setAction(async (taskArgs, hre) => {
        const multiCallFactory = await hre.ethers.getContractFactory('MultiCall')
        const multiCall = await multiCallFactory.attach(taskArgs.multicall)

        // eth.0xe127bd251ab5a499e57034644ef41726c931b45b => teleport.0xd9a41dbe13386c6674d871021106266ea7b27f5c
        let ERC20TransferData = {
            tokenAddress: "0xe127bd251ab5a499e57034644ef41726c931b45b",
            receiver: "0x0000000000000000000000000000000010000007",
            amount: 1,
        }
        let ERC20TransferDataAbi = utils.defaultAbiCoder.encode(["tuple(address,string,uint256)"], [[ERC20TransferData.tokenAddress, ERC20TransferData.receiver, ERC20TransferData.amount]]);

        // teleport.0xd9a41dbe13386c6674d871021106266ea7b27f5c => bsc.0xe9a6bd7ca0fcbe36c2d003872284bbcd47fda8b0
        let dataByte = Buffer.from("efb509250000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d9a41dbe13386c6674d871021106266ea7b27f5c00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000002a307865396136626437636130666362653336633264303033383732323834626263643437666461386230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008746573742d6273630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "hex")
        let RCCData = {
            contractAddress: "0x0000000000000000000000000000000010000007",
            data: dataByte,
        }
        let RCCDataAbi = utils.defaultAbiCoder.encode(["tuple(string,bytes)"], [[RCCData.contractAddress, RCCData.data]]);

        let MultiCallData = {
            destChain: "teleport",
            relayChain: "",
            functions: [BigNumber.from(0),BigNumber.from(2)],
            data: [ERC20TransferDataAbi,RCCDataAbi],
        }

        // need aprove to transfer on eth 
        // yarn hardhat approve --address 0xe127bd251ab5a499e57034644ef41726c931b45b --transfer 0x2302fEe0A495665Bf0d7094F8044553C01376cd4 --amount 1 --network rinkeby

        let res = await multiCall.multiCall(MultiCallData)
        console.log(res)
    })

module.exports = {}