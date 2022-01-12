import { ethers, upgrades } from "hardhat"
import { BigNumber, Signer } from "ethers"
import chai from "chai"

import { Packet, Routing, ClientManager, MockTendermint, MockTransfer, AccessManager } from '../typechain'
import { sha256 } from "ethers/lib/utils"

let client = require("./proto/compiled.js")

const { expect } = chai

describe('Packet', () => {
    let routing: Routing
    let clientManager: ClientManager
    let tendermint: MockTendermint
    let transfer: MockTransfer
    let accessManager: AccessManager
    let accounts: Signer[]
    let packet: Packet
    const srcChainName = "srcChain"
    const destChainName = "destChain"
    const relayChainName = "relayChain"

    before('deploy Packet', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await deployRouting()
        await deployPacket()
        await deployTransfer()
    })

    it("send transfer ERC20 packet and receive ack", async () => {
        let dataByte = Buffer.from("testdata", "utf-8")
        let transferData = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            receiver: (await accounts[3].getAddress()).toString(),
            amount: 1,
            destChain: destChainName,
            relayChain: relayChainName,
        }
        let path = "commitments/" + srcChainName + "/" + destChainName + "/sequences/" + 1
        await transfer.sendTransferERC20(transferData)
        let commit = await packet.commitments(Buffer.from(path, "utf-8"))
        let seq = await packet.getNextSequenceSend(srcChainName, destChainName)
        expect(seq).to.equal(2)
        expect(commit).to.equal(sha256(sha256(dataByte)))

        let sequence: BigNumber = BigNumber.from(1)
        let pkt = {
            sequence: sequence,
            sourceChain: srcChainName,
            destChain: destChainName,
            relayChain: relayChainName,
            ports: ["FT"],
            dataList: [dataByte],
        }
        let ackByte = await transfer.NewAcknowledgement(true, "")
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
        let dataByte = Buffer.from("testdata", "utf-8")
        let transferData = {
            receiver: "receiver",
            destChain: destChainName,
            relayChain: relayChainName,
        }
        let path = "commitments/" + srcChainName + "/" + destChainName + "/sequences/" + 2
        await transfer.sendTransferBase(transferData, { value: 1 })
        let commit = await packet.commitments(Buffer.from(path, "utf-8"))
        let seq = await packet.getNextSequenceSend(srcChainName, destChainName)
        expect(seq).to.equal(3)
        expect(commit).to.equal(sha256(sha256(dataByte)))
        let sequence: BigNumber = BigNumber.from(2)
        let pkt = {
            sequence: sequence,
            sourceChain: srcChainName,
            destChain: destChainName,
            relayChain: relayChainName,
            ports: ["FT"],
            dataList: [dataByte],
        }
        let ackByte = await transfer.NewAcknowledgement(true, "")
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
        let dataByte = Buffer.from("testdata", "utf-8")
        let ackByte = await transfer.NewAcknowledgement(true, "")
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
            dataList: [dataByte],
        }
        await packet.recvPacket(pkt, proof, height)
        let ackPath = "acks/" + destChainName + "/" + srcChainName + "/sequences/" + 1
        let receiptPath = "receipts/" + destChainName + "/" + srcChainName + "/sequences/" + 1
        let macAckSeqPath = "maxAckSeq/" + destChainName + "/" + srcChainName
        let ackCommit = await packet.commitments(Buffer.from(ackPath, "utf-8"))
        expect(ackCommit).to.equal(sha256(ackByte))
        expect(await packet.receipts(Buffer.from(receiptPath, "utf-8"))).to.equal(true)
        expect(await packet.sequences(Buffer.from(macAckSeqPath, "utf-8"))).to.equal(1)
    })

    it("upgrade packet", async () => {
        const mockPacketUpgradeFactory = await ethers.getContractFactory("MockPacketUpgrade")
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
        await clientManager.createClient(relayChainName, tendermint.address, clientStateBuf, consensusStateBuf)
    }

    const deployRouting = async () => {
        const rtFactory = await ethers.getContractFactory('Routing', accounts[0])
        routing = await upgrades.deployProxy(rtFactory, [accessManager.address]) as Routing
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