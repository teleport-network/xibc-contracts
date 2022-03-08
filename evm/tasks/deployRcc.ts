import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS

task("deployRcc", "Deploy Rcc")
    .setAction(async (taskArgs, hre) => {
        const RCCFactory = await hre.ethers.getContractFactory('RCC')
        const rcc = await hre.upgrades.deployProxy(
            RCCFactory,
            [
                String(PACKET_ADDRESS),
                String(CLIENT_MANAGER_ADDRESS),
                String(ACCESS_MANAGER_ADDRESS)
            ]
        )
        await rcc.deployed()

        console.log("Rcc deployed to:", rcc.address.toLocaleLowerCase())
        console.log("export RCC_ADDRESS=%s", rcc.address.toLocaleLowerCase())
        fs.appendFileSync('env.txt', 'export RCC_ADDRESS='+rcc.address.toLocaleLowerCase()+'\n')
    })


task("sendRcc", "Send Rcc")
    .addParam("rcc", "rcc address")
    .setAction(async (taskArgs, hre) => {
        const RCCFactory = await hre.ethers.getContractFactory('RCC')
        const rcc = await RCCFactory.attach(taskArgs.rcc)
        let dataByte = Buffer.from("efb509250000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d9a41dbe13386c6674d871021106266ea7b27f5c00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000002a307865396136626437636130666362653336633264303033383732323834626263643437666461386230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008746573742d6273630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "hex")
        let rccData = {
            contractAddress: "0x0000000000000000000000000000000010000007",
            data: dataByte,
            destChain: "teleport",
            relayChain: "",
        }
        let res =  await rcc.sendRemoteContractCall(rccData)
        console.log(res)
    })
module.exports = {}