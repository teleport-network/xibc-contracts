// import "@nomiclabs/hardhat-web3"
// import { task } from "hardhat/config"
// import fs = require('fs');

// const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
// const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS
// const PACKET_ADDRESS = process.env.PACKET_ADDRESS
// const NOT_PROXY = process.env.NOT_PROXY
// const ENDPOINT_ADDRESS = process.env.ENDPOINT_ADDRESS
// const EXECUTE_ADDRESS = process.env.EXECUTE_ADDRESS

// task("deployPacket", "Deploy Packet")
//     .addParam("chain", "chain name")
//     .addParam("relaychain", "relay chain name")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         if (NOT_PROXY) {
//             const packet = await packetFactory.deploy()
//             await packet.deployed()
//             console.log("Packet deployed  !")
//             console.log("export PACKET_ADDRESS=%s", packet.address.toLocaleLowerCase())
//         } else {
//             const packet = await hre.upgrades.deployProxy(
//                 packetFactory,
//                 [
//                     taskArgs.chain,
//                     taskArgs.relaychain,
//                     String(CLIENT_MANAGER_ADDRESS),
//                     String(ACCESS_MANAGER_ADDRESS)
//                 ]
//             )
//             await packet.deployed()
//             console.log("Packet deployed to:", packet.address.toLocaleLowerCase())
//             console.log("export PACKET_ADDRESS=%s", packet.address.toLocaleLowerCase())
//             fs.appendFileSync('env.txt', 'export PACKET_ADDRESS=' + packet.address.toLocaleLowerCase() + '\n')
//         }
//     })

// task("checkRouting", "query")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         const packet = await packetFactory.attach(String(PACKET_ADDRESS))

//         console.log(await packet.endpoint())
//         console.log(await packet.execute())
//     })

// task("initPacket", "set endpoint and execute contract addresses")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         const packet = await packetFactory.attach(String(PACKET_ADDRESS))

//         let packetRec = await packet.initEndpoint(String(ENDPOINT_ADDRESS), String(EXECUTE_ADDRESS))
//         console.log(packetRec)
//     })

// task("queryRecipt", "query recipt")
//     .addParam("srcchain", "srcChain")
//     .addParam("sequence", "srcChain")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         const packet = await packetFactory.attach(String(PACKET_ADDRESS))
//         let key = taskArgs.srcchain + "/" + taskArgs.sequence
//         let packetRec = await packet.receipts(Buffer.from(key, "utf-8"))
//         console.log(packetRec)
//     })

// task("queryCommit", "query commit")
//     .addParam("srcchain", "srcChain")
//     .addParam("dstchain", "srcChain")
//     .addParam("sequence", "srcChain")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         const packet = await packetFactory.attach(String(PACKET_ADDRESS))
//         let key = "commitments/" + taskArgs.srcchain + "/" + taskArgs.dstchain + "/sequences/" + taskArgs.sequence
//         let packetRec = await packet.commitments(Buffer.from(key, "utf-8"))
//         console.log(packetRec)
//     })

// task("getAckStatus", "get ack status")
//     .addParam("dstchain", "srcChain")
//     .addParam("sequence", "srcChain")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         const packet = await packetFactory.attach(String(PACKET_ADDRESS))

//         let state = await packet.getAckStatus(taskArgs.dstchain, taskArgs.sequence)
//         console.log(state)
//     })

// task("getPacketFee", "query packet fee")
//     .addParam("dstchain", "srcChain")
//     .addParam("sequence", "srcChain")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         const packet = await packetFactory.attach(String(PACKET_ADDRESS))

//         let key = taskArgs.dstchain + "/" + taskArgs.sequence
//         let Fees = await packet.packetFees(Buffer.from(key, "utf-8"))
//         console.log(Fees)
//     })

// task("addPacketFee", "set packet fee")
//     .addParam("dst", "destination chain name")
//     .addParam("sequence", "sequence")
//     .addParam("amount", "amount")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         const packet = await packetFactory.attach(String(PACKET_ADDRESS))

//         let tx = await packet.addPacketFee(
//             taskArgs.dst,
//             taskArgs.sequence,
//             taskArgs.amount,
//         )

//         console.log(tx)
//         console.log("txHash: ", tx.hash)
//         console.log("blockHash: ", tx.blockHash)
//     })

// task("getChainName", "query packet chain name")
//     .setAction(async (taskArgs, hre) => {
//         const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
//         const packet = await packetFactory.attach(String(PACKET_ADDRESS))

//         console.log(await packet.chainName())

//     })

// module.exports = {}