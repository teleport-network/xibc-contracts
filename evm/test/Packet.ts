import { Signer, BigNumber, utils } from "ethers"
import chai from "chai"
import { MockTransfer, Packet, ClientManager, Routing, MockTendermint, AccessManager, ERC20 } from '../typechain'
import { sha256, keccak256 } from "ethers/lib/utils"

const { expect } = chai
const { web3, ethers, upgrades } = require("hardhat")

let client = require("./proto/compiled.js")

describe('Packet', () => {
    let routing: Routing
    let clientManager: ClientManager
    let tendermint: MockTendermint
    let transfer: MockTransfer
    let accessManager: AccessManager
    let accounts: Signer[]
    let packet: Packet
    let erc20: ERC20
    const srcChainName = "srcChain"
    const destChainName = "destChain"
    const relayChainName = ""

    before('deploy Packet', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await deployRouting()
        await deployPacket()
        await deployTransfer()
        await deployToken()
    })

    it("send transfer ERC20 packet and receive ack", async () => {
        let account = (await accounts[0].getAddress()).toString()
        let transferData = {
            tokenAddress: erc20.address.toLocaleLowerCase(),
            receiver: (await accounts[3].getAddress()).toString().toLocaleLowerCase(),
            amount: 1,
            destChain: destChainName,
            relayChain: relayChainName,
        }
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let Fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }
        let seqU64 = 1
        let packetData = {
            srcChain: srcChainName,
            destChain: transferData.destChain,
            sequence: seqU64,
            sender: (await accounts[0].getAddress()).toString().toLocaleLowerCase(),
            receiver: transferData.receiver,
            amount: amount,
            token: transferData.tokenAddress,
            oriToken: ""
        }
        let packetDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    packetData.srcChain,
                    packetData.destChain,
                    packetData.sequence,
                    packetData.sender,
                    packetData.receiver,
                    packetData.amount,
                    packetData.token,
                    packetData.oriToken
                ]
            ]
        );
        let path = "commitments/" + srcChainName + "/" + destChainName + "/sequences/" + 1
        await transfer.sendTransfer(transferData, Fee)
        let commit = await packet.commitments(Buffer.from(path, "utf-8"))
        let seq = await packet.getNextSequenceSend(srcChainName, destChainName)
        expect(seq).to.equal(2)
        expect(commit).to.equal(sha256(sha256(packetDataBz)))
        let sequence: BigNumber = BigNumber.from(1)
        let pkt = {
            sequence: sequence,
            sourceChain: srcChainName,
            destChain: destChainName,
            relayChain: relayChainName,
            ports: ["FT"],
            dataList: [packetDataBz],
        }
        let ackByte = utils.defaultAbiCoder.encode(
            ["tuple(bytes[],string,string)"],
            [
                [
                    ["0x01"],
                    "",
                    account.toLowerCase(),
                ]
            ]
        );
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        await packet.acknowledgePacket(pkt, ackByte, proof, height)
        commit = await packet.commitments(Buffer.from(path, "utf-8"))
        expect(commit).to.equal('0x0000000000000000000000000000000000000000000000000000000000000000')
    })

    it("send transfer Base packet and receive ack", async () => {
        let account = (await accounts[0].getAddress()).toString()
        let transferData = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            receiver: "receiver",
            amount: 1,
            destChain: destChainName,
            relayChain: relayChainName,
        }
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let Fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }
        let seqU64 = 2
        let packetData = {
            srcChain: srcChainName,
            destChain: transferData.destChain,
            sequence: seqU64,
            sender: (await accounts[0].getAddress()).toString().toLocaleLowerCase(),
            receiver: transferData.receiver,
            amount: amount,
            token: "0x0000000000000000000000000000000000000000",
            oriToken: ""
        }
        let packetDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    packetData.srcChain,
                    packetData.destChain,
                    packetData.sequence,
                    packetData.sender,
                    packetData.receiver,
                    packetData.amount,
                    packetData.token,
                    packetData.oriToken
                ]
            ]
        );
        let path = "commitments/" + srcChainName + "/" + destChainName + "/sequences/" + 2
        await transfer.sendTransfer(transferData, Fee, { value: 1 })
        let commit = await packet.commitments(Buffer.from(path, "utf-8"))
        let seq = await packet.getNextSequenceSend(srcChainName, destChainName)
        expect(seq).to.equal(3)
        expect(commit).to.equal(sha256(sha256(packetDataBz)))
        let sequence: BigNumber = BigNumber.from(2)
        let pkt = {
            sequence: sequence,
            sourceChain: srcChainName,
            destChain: destChainName,
            relayChain: relayChainName,
            ports: ["FT"],
            dataList: [packetDataBz],
        }
        let ackByte = utils.defaultAbiCoder.encode(
            ["tuple(bytes[],string,string)"],
            [
                [
                    ["0x01"],
                    "",
                    account.toLowerCase(),
                ]
            ]
        );
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        await packet.acknowledgePacket(pkt, ackByte, proof, height)
        commit = await packet.commitments(Buffer.from(path, "utf-8"))
        expect(commit).to.equal('0x0000000000000000000000000000000000000000000000000000000000000000')
    })

    it("receive packet and write ack", async () => {
        let account = (await accounts[0].getAddress()).toString()
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let seqU64 = 1
        let packetData = {
            srcChain: destChainName,
            destChain: srcChainName,
            sequence: seqU64,
            sender: (await accounts[3].getAddress()).toString().toLocaleLowerCase(),
            receiver: (await accounts[0].getAddress()).toString().toLocaleLowerCase(),
            amount: amount,
            token: "",
            oriToken: "0x0000000000000000000000000000000000000000"
        }
        let packetDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    packetData.srcChain,
                    packetData.destChain,
                    packetData.sequence,
                    packetData.sender,
                    packetData.receiver,
                    packetData.amount,
                    packetData.token,
                    packetData.oriToken
                ]
            ]
        );
        let ackByte = utils.defaultAbiCoder.encode(
            ["tuple(bytes[],string,string)"],
            [
                [
                    ["0x01"],
                    "",
                    account.toLowerCase(),
                ]
            ]
        );
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let sequence: BigNumber = BigNumber.from(1)
        let pkt = {
            sequence: sequence,
            sourceChain: destChainName,
            destChain: srcChainName,
            relayChain: relayChainName,
            ports: ["FT"],
            dataList: [packetDataBz],
        }
        await packet.recvPacket(pkt, proof, height)
        let ackPath = "acks/" + destChainName + "/" + srcChainName + "/sequences/" + 1
        let receiptPath = destChainName + "/" + srcChainName + "/" + 1
        let maxAckSeqPath = destChainName + "/" + srcChainName
        let ackCommit = await packet.commitments(Buffer.from(ackPath, "utf-8"))
        expect(ackCommit).to.equal(sha256(ackByte))
        expect(await packet.receipts(Buffer.from(receiptPath, "utf-8"))).to.equal(true)
        expect(await packet.sequences(Buffer.from(maxAckSeqPath, "utf-8"))).to.equal(1)
    })

    it("upgrade packet", async () => {
        const mockPacketUpgradeFactory = await ethers.getContractFactory("MockPacket")
        const upgradedPacket = await upgrades.upgradeProxy(packet.address, mockPacketUpgradeFactory)
        expect(upgradedPacket.address).to.eq(packet.address)

        await upgradedPacket.setVersion(2)
        const version = await upgradedPacket.version()
        expect(2).to.eq(version.toNumber())
    })

    const deployAccessManager = async () => {
        const accessFactory = await ethers.getContractFactory('AccessManager')
        accessManager = (await upgrades.deployProxy(accessFactory, [await accounts[0].getAddress()])) as AccessManager
    }

    const deployClientManager = async () => {
        const msrFactory = await ethers.getContractFactory('ClientManager', accounts[0])
        clientManager = (await upgrades.deployProxy(msrFactory, [srcChainName, accessManager.address])) as ClientManager
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
    }

    const deployRouting = async () => {
        const rtFactory = await ethers.getContractFactory('Routing', accounts[0])
        routing = await upgrades.deployProxy(rtFactory, [accessManager.address]) as Routing
    }

    const deployToken = async () => {
        const tokenFac = await ethers.getContractFactory("testToken")
        erc20 = await tokenFac.deploy("test", "test")
        await erc20.deployed()

        erc20.mint(await accounts[0].getAddress(), 1000)
        erc20.approve(transfer.address, 100000)
        expect((await erc20.balanceOf(await accounts[0].getAddress())).toString()).to.eq("1000")
    }

    const deployPacket = async () => {
        const pkFactory = await ethers.getContractFactory(
            'Packet',
            { signer: accounts[0], }
        )
        packet = await upgrades.deployProxy(
            pkFactory,
            [
                clientManager.address,
                routing.address,
                accessManager.address,
            ]
        ) as Packet
    }

    const deployTransfer = async () => {
        const transferFactory = await ethers.getContractFactory('MockTransfer', accounts[0])
        transfer = await upgrades.deployProxy(
            transferFactory,
            [
                packet.address,
                clientManager.address,
                accessManager.address
            ]
        ) as MockTransfer
        await routing.addRouting("FT", transfer.address)
    }
})