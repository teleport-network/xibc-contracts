import { Signer, utils } from "ethers"
import chai from "chai"
import { RCC, Proxy, Routing, ClientManager, MockTendermint, Transfer, AccessManager, MockPacket, ERC20, MultiCall } from '../typechain'
import { web3 } from "hardhat"
import { keccak256, sha256 } from "ethers/lib/utils"
const { ethers, upgrades } = require("hardhat")
const { expect } = chai

let client = require("./proto/compiled.js")

describe('Proxy', () => {
    let rcc: RCC
    let accounts: Signer[]
    let mockPacket: MockPacket
    let clientManager: ClientManager
    let routing: Routing
    let tendermint: MockTendermint
    let accessManager: AccessManager
    let transfer: Transfer
    let multiCall: MultiCall
    let proxy: Proxy
    let erc20: ERC20
    const srcChainName = "srcChain"
    const destChainName = "destChain"

    before('deploy Proxy', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await deployHost()
        await deployRouting()
        await deployMockPacket()
        await deployTransfer()
        await deployToken()
        await deployRCC()
        await deployMultiCall()
        await deployProxy()
    })

    it("send ERC20", async () => {
        let sender = (await accounts[0].getAddress()).toLocaleLowerCase()
        let reciver = (await accounts[1].getAddress()).toLocaleLowerCase()
        let refundAddressOnTeleport = await accounts[2].getAddress()
        let feeAmount = 500

        await erc20.approve(transfer.address, 1000)
        await erc20.approve(multiCall.address, 1000)

        let allowance = await erc20.allowance(sender, transfer.address.toLocaleLowerCase())
        expect(allowance.toNumber()).to.eq(1000)
        allowance = await erc20.allowance(sender, multiCall.address.toLocaleLowerCase())
        expect(allowance.toNumber()).to.eq(1000)

        let ERC20TransferData = {
            tokenAddress: erc20.address.toLocaleLowerCase(),
            receiver: "0x0000000000000000000000000000000010000007", // agent address
            amount: 1000,
        }

        let rccTransfer = {
            tokenAddress: "0x9999999999999999999999999999999999999999", // erc20 in teleport
            receiver: reciver,
            amount: 500,
            destChain: "eth-test",// double jump destChain
            relayChain: "",
        }

        let result = await proxy.send(
            refundAddressOnTeleport,
            destChainName, // teleport
            ERC20TransferData,
            rccTransfer,
            feeAmount,
        )
        // console.log(result)
        expect(true).to.eq(result[1])

        let Fee = {
            tokenAddress: erc20.address,
            amount: 1000,
        }


        await multiCall.multiCall(result[0], Fee)

        let amount = web3.utils.hexToBytes("0x00000000000000000000000000000000000000000000000000000000000003e8")
        let seqU64 = 1
        let ERC20TransferPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sequence: seqU64,
            sender: sender,
            receiver: "0x0000000000000000000000000000000010000007",
            amount: amount,
            token: ERC20TransferData.tokenAddress,
            oriToken: ""
        }
        let ERC20TransferPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    ERC20TransferPacketData.srcChain,
                    ERC20TransferPacketData.destChain,
                    ERC20TransferPacketData.sequence,
                    ERC20TransferPacketData.sender,
                    ERC20TransferPacketData.receiver,
                    ERC20TransferPacketData.amount,
                    ERC20TransferPacketData.token,
                    ERC20TransferPacketData.oriToken
                ]
            ]
        );
        let portBytes = Buffer.from("FT", "utf-8")
        let packetDataBytes = Buffer.from(web3.utils.hexToBytes(ERC20TransferPacketDataBz))
        let lengthSum = portBytes.length + packetDataBytes.length
        let sum = Buffer.concat([portBytes, packetDataBytes], lengthSum)
        let ERC20TransferPacketDataBzHash = Buffer.from(web3.utils.hexToBytes(sha256(sum)))
        let id = sha256(Buffer.from(srcChainName + "/" + destChainName + "/" + 1))
        const agentAbi = web3.eth.abi.encodeFunctionCall(
            {
                name: 'send',
                type: 'function',
                inputs: [
                    {
                        "internalType": "bytes",
                        "name": "id",
                        "type": "bytes"
                    },
                    {
                        "internalType": "address",
                        "name": "tokenAddress",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "refundAddressOnTeleport",
                        "type": "address"
                    },
                    {
                        "internalType": "string",
                        "name": "receiver",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "destChain",
                        "type": "string"
                    },
                    {
                        "internalType": "uint256",
                        "name": "feeAmount",
                        "type": "uint256"
                    }
                ],
            },
            [
                id,
                rccTransfer.tokenAddress,
                refundAddressOnTeleport,
                rccTransfer.receiver,
                rccTransfer.destChain,
                feeAmount.toString(),
            ]
        )
        let RccPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sequence: seqU64,
            sender: sender,
            contractAddress: "0x0000000000000000000000000000000010000007",
            data: web3.utils.hexToBytes(agentAbi),
        }
        let RccPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes)"],
            [
                [
                    RccPacketData.srcChain,
                    RccPacketData.destChain,
                    RccPacketData.sequence,
                    RccPacketData.sender,
                    RccPacketData.contractAddress,
                    RccPacketData.data,
                ]
            ]
        );
        portBytes = Buffer.from("CONTRACT", "utf-8")
        packetDataBytes = Buffer.from(web3.utils.hexToBytes(RccPacketDataBz))
        lengthSum = portBytes.length + packetDataBytes.length
        sum = Buffer.concat([portBytes, packetDataBytes], lengthSum)
        let RccPacketDataBzHash = Buffer.from(web3.utils.hexToBytes(sha256(sum)))

        lengthSum = ERC20TransferPacketDataBzHash.length + RccPacketDataBzHash.length
        sum = Buffer.concat([ERC20TransferPacketDataBzHash, RccPacketDataBzHash], lengthSum)
        let path = "commitments/" + srcChainName + "/" + destChainName + "/sequences/" + 1
        let commitment = await mockPacket.commitments(Buffer.from(path, "utf-8"))
        expect(commitment.toString()).to.eq(sha256(sum))

        let outToken = (await transfer.outTokens(erc20.address, destChainName))
        expect(outToken).to.eq(ERC20TransferData.amount)
    })

    it("send Base", async () => {
        let sender = (await accounts[0].getAddress()).toLocaleLowerCase()
        let reciver = (await accounts[1].getAddress()).toLocaleLowerCase()
        let refundAddressOnTeleport = await accounts[2].getAddress()
        let zeroAddress = "0x0000000000000000000000000000000000000000"
        let feeAmount = 500

        let transferData = {
            tokenAddress: zeroAddress,
            receiver: "0x0000000000000000000000000000000010000007", // agent address
            amount: 1000,
        }
        let rccTransferData = {
            tokenAddress: "0x9999999999999999999999999999999999999999", // erc20 in teleport
            receiver: reciver,
            amount: 500,
            destChain: "eth-test",// double jump destChain
            relayChain: "",
        }
        let Fee = {
            tokenAddress: zeroAddress,
            amount: 1000,
        }
        let result = await proxy.send(
            refundAddressOnTeleport,
            destChainName, // teleport 
            transferData,
            rccTransferData,
            feeAmount,
        )
        expect(true).to.eq(result[1])

        let value = transferData.amount + Fee.amount

        await multiCall.multiCall(result[0], Fee, { value: value })

        let amount = web3.utils.hexToBytes("0x00000000000000000000000000000000000000000000000000000000000003e8")
        let seqU64 = 2
        let BaseTransferPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sequence: seqU64,
            sender: sender,
            receiver: "0x0000000000000000000000000000000010000007",
            amount: amount,
            token: zeroAddress,
            oriToken: ""
        }
        let BaseTransferPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    BaseTransferPacketData.srcChain,
                    BaseTransferPacketData.destChain,
                    BaseTransferPacketData.sequence,
                    BaseTransferPacketData.sender,
                    BaseTransferPacketData.receiver,
                    BaseTransferPacketData.amount,
                    BaseTransferPacketData.token,
                    BaseTransferPacketData.oriToken
                ]
            ]
        );
        let portBytes = Buffer.from("FT", "utf-8")
        let packetDataBytes = Buffer.from(web3.utils.hexToBytes(BaseTransferPacketDataBz))
        let lengthSum = portBytes.length + packetDataBytes.length
        let sum = Buffer.concat([portBytes, packetDataBytes], lengthSum)
        let BaseTransferPacketDataBzHash = Buffer.from(web3.utils.hexToBytes(sha256(sum)))
        let id = sha256(Buffer.from(srcChainName + "/" + destChainName + "/" + 2))
        const agentAbi = web3.eth.abi.encodeFunctionCall(
            {
                name: 'send',
                type: 'function',
                inputs: [
                    {
                        "internalType": "bytes",
                        "name": "id",
                        "type": "bytes"
                    },
                    {
                        "internalType": "address",
                        "name": "tokenAddress",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "refundAddressOnTeleport",
                        "type": "address"
                    },
                    {
                        "internalType": "string",
                        "name": "receiver",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "destChain",
                        "type": "string"
                    },
                    {
                        "internalType": "uint256",
                        "name": "feeAmount",
                        "type": "uint256"
                    }
                ],
            },
            [
                id,
                rccTransferData.tokenAddress,
                refundAddressOnTeleport,
                rccTransferData.receiver,
                rccTransferData.destChain,
                feeAmount.toString(),
            ]
        )

        let RccPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sequence: seqU64,
            sender: sender,
            contractAddress: "0x0000000000000000000000000000000010000007",
            data: web3.utils.hexToBytes(agentAbi),
        }
        let RccPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes)"],
            [
                [
                    RccPacketData.srcChain,
                    RccPacketData.destChain,
                    RccPacketData.sequence,
                    RccPacketData.sender,
                    RccPacketData.contractAddress,
                    RccPacketData.data,
                ]
            ]
        );
        portBytes = Buffer.from("CONTRACT", "utf-8")
        packetDataBytes = Buffer.from(web3.utils.hexToBytes(RccPacketDataBz))
        lengthSum = portBytes.length + packetDataBytes.length
        sum = Buffer.concat([portBytes, packetDataBytes], lengthSum)
        let RccPacketDataBzHash = Buffer.from(web3.utils.hexToBytes(sha256(sum)))

        lengthSum = BaseTransferPacketDataBzHash.length + RccPacketDataBzHash.length
        sum = Buffer.concat([BaseTransferPacketDataBzHash, RccPacketDataBzHash], lengthSum)
        let path = "commitments/" + srcChainName + "/" + destChainName + "/sequences/" + 2
        let commitment = await mockPacket.commitments(Buffer.from(path, "utf-8"))
        expect(commitment.toString()).to.eq(sha256(sum))
        let outToken = (await transfer.outTokens(zeroAddress, destChainName))
        expect(outToken).to.eq(transferData.amount)
    })

    it("refund erc20 token", async () => {
        let sender = (await accounts[0].getAddress()).toLocaleLowerCase()
        let reciver = (await accounts[1].getAddress()).toLocaleLowerCase()
        let refundAddressOnTeleport = await accounts[2].getAddress()

        let transferData = {
            tokenAddress: erc20.address.toLocaleLowerCase(),
            receiver: "0x0000000000000000000000000000000010000007", // agent address
            amount: 1000,
        }
        let balances = await erc20.balanceOf(sender)
        expect(1046576).to.eq(balances)
        let rccTransferData = {
            tokenAddress: "0x9999999999999999999999999999999999999999", // erc20 in teleport
            receiver: reciver,
            amount: 1000,
            destChain: "eth-test",// double jump destChain
            relayChain: "",
        }
        let amount = web3.utils.hexToBytes("0x00000000000000000000000000000000000000000000000000000000000003e8")
        let seqU64 = 1
        let ERC20TransferPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sequence: seqU64,
            sender: sender,
            receiver: "0x0000000000000000000000000000000010000007",
            amount: amount,
            token: transferData.tokenAddress,
            oriToken: ""
        }
        let ERC20TransferPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    ERC20TransferPacketData.srcChain,
                    ERC20TransferPacketData.destChain,
                    ERC20TransferPacketData.sequence,
                    ERC20TransferPacketData.sender,
                    ERC20TransferPacketData.receiver,
                    ERC20TransferPacketData.amount,
                    ERC20TransferPacketData.token,
                    ERC20TransferPacketData.oriToken
                ]
            ]
        );
        let id = sha256(Buffer.from(srcChainName + "/" + destChainName + "/" + 1))
        const agentAbi = web3.eth.abi.encodeFunctionCall(
            {
                name: 'send',
                type: 'function',
                inputs: [
                    {
                        "internalType": "bytes",
                        "name": "id",
                        "type": "bytes"
                    },
                    {
                        "internalType": "address",
                        "name": "tokenAddress",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "refundAddressOnTeleport",
                        "type": "address"
                    },
                    {
                        "internalType": "string",
                        "name": "receiver",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "destChain",
                        "type": "string"
                    },
                    {
                        "internalType": "uint256",
                        "name": "feeAmount",
                        "type": "uint256"
                    }
                ],
            },
            [
                id,
                rccTransferData.tokenAddress,
                refundAddressOnTeleport,
                rccTransferData.receiver,
                rccTransferData.destChain,
                "500",
            ]
        )

        let RccPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sequence: seqU64,
            sender: sender,
            contractAddress: "0x0000000000000000000000000000000010000007",
            data: web3.utils.hexToBytes(agentAbi),
        }
        let RccPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes)"],
            [
                [
                    RccPacketData.srcChain,
                    RccPacketData.destChain,
                    RccPacketData.sequence,
                    RccPacketData.sender,
                    RccPacketData.contractAddress,
                    RccPacketData.data,
                ]
            ]
        );
        let pkt = {
            sequence: 1,
            sourceChain: srcChainName,
            destChain: destChainName,
            relayChain: "",
            ports: ["FT", "CONTRACT"],
            dataList: [ERC20TransferPacketDataBz, RccPacketDataBz],
        }
        let Erc20Ack = utils.defaultAbiCoder.encode(
            ["tuple(bytes[],string,string)"],
            [
                [
                    [],
                    "1: onRecvPackt: binding is not exist",
                    sender,
                ]
            ]
        );
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        await mockPacket.acknowledgePacket(pkt, Erc20Ack, proof, height)
        balances = await erc20.balanceOf(ERC20TransferPacketData.sender)
        expect(balances).to.eq(1048576)
        let outToken = (await transfer.outTokens(erc20.address, destChainName))
        expect(outToken).to.eq(0)
    })

    it("refund native token", async () => {
        let sender = (await accounts[0].getAddress()).toLocaleLowerCase()
        let reciver = (await accounts[1].getAddress()).toLocaleLowerCase()
        let refundAddressOnTeleport = await accounts[2].getAddress()

        let zeroAddress = "0x0000000000000000000000000000000000000000"
        let rccTransfer = {
            tokenAddress: "0x9999999999999999999999999999999999999999", // erc20 in teleport
            receiver: reciver,
            amount: 1000,
            destChain: "eth-test",// double jump destChain
            relayChain: "",
        }
        let amount = web3.utils.hexToBytes("0x00000000000000000000000000000000000000000000000000000000000003e8")
        let seqU64 = 2
        let BaseTransferPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sequence: seqU64,
            sender: sender,
            receiver: "0x0000000000000000000000000000000010000007",
            amount: amount,
            token: zeroAddress,
            oriToken: ""
        }
        let BaseTransferPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    BaseTransferPacketData.srcChain,
                    BaseTransferPacketData.destChain,
                    BaseTransferPacketData.sequence,
                    BaseTransferPacketData.sender,
                    BaseTransferPacketData.receiver,
                    BaseTransferPacketData.amount,
                    BaseTransferPacketData.token,
                    BaseTransferPacketData.oriToken
                ]
            ]
        );
        let id = sha256(Buffer.from(srcChainName + "/" + destChainName + "/" + 2))
        const agentAbi = web3.eth.abi.encodeFunctionCall(
            {
                name: 'send',
                type: 'function',
                inputs: [
                    {
                        "internalType": "bytes",
                        "name": "id",
                        "type": "bytes"
                    },
                    {
                        "internalType": "address",
                        "name": "tokenAddress",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "refundAddressOnTeleport",
                        "type": "address"
                    },
                    {
                        "internalType": "string",
                        "name": "receiver",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "destChain",
                        "type": "string"
                    },
                    {
                        "internalType": "uint256",
                        "name": "feeAmount",
                        "type": "uint256"
                    }
                ],
            },
            [
                id,
                rccTransfer.tokenAddress,
                refundAddressOnTeleport,
                rccTransfer.receiver,
                rccTransfer.destChain,
                "500",
            ]
        )

        let RccPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sequence: seqU64,
            sender: sender,
            contractAddress: "0x0000000000000000000000000000000010000007",
            data: web3.utils.hexToBytes(agentAbi),
        }
        let RccPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes)"],
            [
                [
                    RccPacketData.srcChain,
                    RccPacketData.destChain,
                    RccPacketData.sequence,
                    RccPacketData.sender,
                    RccPacketData.contractAddress,
                    RccPacketData.data,
                ]
            ]
        )
        let pkt = {
            sequence: 2,
            sourceChain: srcChainName,
            destChain: destChainName,
            relayChain: "",
            ports: ["FT", "CONTRACT"],
            dataList: [BaseTransferPacketDataBz, RccPacketDataBz],
        }
        let Erc20Ack = utils.defaultAbiCoder.encode(
            ["tuple(bytes[],string,string)"],
            [
                [
                    [],
                    "1: onRecvPackt: binding is not exist",
                    sender
                ]
            ]
        )
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        await mockPacket.acknowledgePacket(pkt, Erc20Ack, proof, height)

        let outToken = (await transfer.outTokens(zeroAddress, destChainName))
        expect(outToken).to.eq(0)
    })

    const deployTransfer = async () => {
        const transferFactory = await ethers.getContractFactory('Transfer', accounts[0])
        transfer = await upgrades.deployProxy(
            transferFactory,
            [
                mockPacket.address,
                clientManager.address,
                accessManager.address
            ]
        ) as Transfer
        await routing.addRouting("FT", transfer.address)
    }

    const deployMockPacket = async () => {
        const mockPacketFactory = await ethers.getContractFactory(
            'MockPacket',
            { signer: accounts[0], }
        )
        mockPacket = await upgrades.deployProxy(
            mockPacketFactory,
            [
                clientManager.address,
                routing.address,
                accessManager.address,
            ]
        ) as MockPacket
    }

    const deployRCC = async () => {
        const RCCFactory = await ethers.getContractFactory('RCC')
        rcc = await upgrades.deployProxy(
            RCCFactory,
            [
                mockPacket.address,
                clientManager.address,
                accessManager.address
            ]
        ) as RCC
        await routing.addRouting("CONTRACT", rcc.address)
    }

    const deployProxy = async () => {
        const ProxyFactory = await ethers.getContractFactory('Proxy')
        proxy = await upgrades.deployProxy(
            ProxyFactory,
            [
                clientManager.address,
                mockPacket.address
            ]
        ) as Proxy
    }

    const deployAccessManager = async () => {
        const accessFactory = await ethers.getContractFactory('AccessManager')
        accessManager = (await upgrades.deployProxy(accessFactory, [await accounts[0].getAddress()])) as AccessManager
    }

    const deployClientManager = async () => {
        const msrFactory = await ethers.getContractFactory('ClientManager', accounts[0])
        clientManager = (await upgrades.deployProxy(msrFactory, [srcChainName, accessManager.address])) as ClientManager
    }

    const deployMultiCall = async () => {
        const multiCallFactory = await ethers.getContractFactory('MultiCall')
        multiCall = await upgrades.deployProxy(
            multiCallFactory,
            [
                mockPacket.address,
                clientManager.address,
                transfer.address,
                rcc.address,
            ]
        ) as MultiCall
        let role = Buffer.from("MULTISEND_ROLE", "utf-8")
        await accessManager.grantRole(keccak256(role), multiCall.address)
    }

    const deployToken = async () => {
        const tokenFac = await ethers.getContractFactory("testToken")
        erc20 = await tokenFac.deploy("test", "test")
        await erc20.deployed()

        erc20.mint(await accounts[0].getAddress(), 1048576)
        expect((await erc20.balanceOf(await accounts[0].getAddress())).toString()).to.eq("1048576")
    }

    const deployHost = async () => {
        const hostFac = await ethers.getContractFactory("Host")
        const host = await hostFac.deploy()
        await host.deployed()
    }

    const deployRouting = async () => {
        const routingFac = await ethers.getContractFactory("Routing")
        routing = await upgrades.deployProxy(routingFac, [accessManager.address]) as Routing
    }

    const deployTendermint = async () => {
        const ClientStateCodec = await ethers.getContractFactory('ClientStateCodec')
        const clientStateCodec = await ClientStateCodec.deploy()
        await clientStateCodec.deployed()

        const ConsensusStateCodec = await ethers.getContractFactory('ConsensusStateCodec')
        const consensusStateCodec = await ConsensusStateCodec.deploy()
        await consensusStateCodec.deployed()

        const tmFactory = await ethers.getContractFactory(
            'MockTendermint',
            {
                signer: accounts[0],
                libraries: {
                    ClientStateCodec: clientStateCodec.address,
                    ConsensusStateCodec: consensusStateCodec.address
                },
            }
        )
        tendermint = await upgrades.deployProxy(
            tmFactory,
            [clientManager.address],
            { "unsafeAllowLinkedLibraries": true }
        ) as MockTendermint

        // create light client
        let clientState = {
            chainId: destChainName,
            trustLevel: { numerator: 1, denominator: 3 },
            trustingPeriod: 10 * 24 * 60 * 60,
            unbondingPeriod: 1814400,
            maxClockDrift: 10,
            latestHeight: { revisionNumber: 0, revisionHeight: 3893 },
            merklePrefix: { key_prefix: Buffer.from("74696263", "hex") },
            timeDelay: 10,
        }

        let consensusState = {
            timestamp: { secs: 1631155726, nanos: 5829, },
            root: Buffer.from("gd17k2js3LzwChS4khcRYMwVFWMPQX4TfJ9wG3MP4gs=", "base64"),
            nextValidatorsHash: Buffer.from("B1fwvGc/jfJtYdPnS7YYGsnfiMCaEQDG+t4mRgS0xHg=", "base64")
        }

        accounts = await ethers.getSigners()

        const ProofCodec = await ethers.getContractFactory('ProofCodec')
        const proofCodec = await ProofCodec.deploy()
        await proofCodec.deployed()

        let clientStateBuf = client.ClientState.encode(clientState).finish()
        let consensusStateBuf = client.ConsensusState.encode(consensusState).finish()
        await clientManager.createClient(destChainName, tendermint.address, clientStateBuf, consensusStateBuf)

        let signer = await accounts[0].getAddress()
        let ret1 = await clientManager.registerRelayer(destChainName, signer)
        expect(ret1.blockNumber).to.greaterThan(0)
    }
})
