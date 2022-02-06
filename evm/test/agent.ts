import { BigNumber, Signer } from "ethers"
import chai from "chai"
import { RCC, Routing, ClientManager, MockTendermint, MockTransfer, AccessManager, MockPacket, ERC20, Agent } from '../typechain'
import { web3 } from "hardhat"
import { sha256 } from "ethers/lib/utils"
const { ethers, upgrades } = require("hardhat")
const { expect } = chai

let client = require("./proto/compiled.js")

describe('Agent', () => {
    let rcc: RCC
    let accounts: Signer[]
    let mockPacket: MockPacket
    let clientManager: ClientManager
    let routing: Routing
    let tendermint: MockTendermint
    let accessManager: AccessManager
    let mockTransfer: MockTransfer
    let agent: Agent
    let erc20: ERC20
    const srcChainName = "srcChain"
    const destChainName = "destChain"

    before('deploy Agent', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await deployHost()
        await deployRouting()
        await deployMockPacket()
        await deployMockTransfer()
        await deployToken()
        await deployRCC()
        await deployAgent()
    })

    it("send", async () => {
        let account = (await accounts[0].getAddress()).toString()
        let amount = web3.utils.hexToBytes("0x000000000000000000000000000000000000000000000000000000000010000")
        let erc20PacketData = {
            srcChain: destChainName,
            destChain: srcChainName,
            sender: account.toLowerCase(),
            receiver: agent.address.toLowerCase(),
            amount: amount,
            token: "0x0000000000000000000000000000000010000011",
            oriToken: null
        }
        let erc20PacketDataBz = client.TokenTransfer.encode(erc20PacketData).finish()

        let dataByte = Buffer.from("efb50925000000000000000000000000000000000000000000000000000000000000002000000000000000000000000067d269191c92caf3cd7723f116c85e6e9bf5593300000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000002a30786633396664366535316161643838663666346365366162383832373237396366666662393232363600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000964657374436861696e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "hex")
        let packetData = {
            srcChain: destChainName,
            destChain: srcChainName,
            sender: account.toLowerCase(),
            contractAddress: agent.address,
            data: dataByte,
        }
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let transferByte = client.RemoteContractCall.encode(packetData).finish()
        let sequence: BigNumber = BigNumber.from(1)
        let pac = {
            sequence: sequence,
            sourceChain: packetData.srcChain,
            destChain: packetData.destChain,
            relayChain: "",
            ports: ["FT", "CONTRACT"],
            dataList: [erc20PacketDataBz, transferByte],
        }
        await mockTransfer.bindToken(erc20.address, erc20PacketData.token, erc20PacketData.srcChain)

        let trace = await mockTransfer.bindingTraces(erc20PacketData.srcChain + "/" + erc20PacketData.token)
        expect(trace.toString()).to.eq(erc20.address)

        await mockPacket.recvPacket(pac, proof, height)

        expect((await erc20.balanceOf(agent.address)).toString()).to.eq("1047576")

        let outToken = (await mockTransfer.outTokens(erc20.address, destChainName))
        expect(outToken).to.eq(0)

        expect(await agent.balances(account.toLowerCase(), erc20.address.toLowerCase())).to.eq("1047576")
        expect(await agent.supplies(erc20.address.toLowerCase())).to.eq("1047576")
        expect((await agent.sequences(srcChainName + "/" + destChainName + "/1")).sent).to.eq(true)
        expect(await mockPacket.getNextSequenceSend(srcChainName, destChainName)).to.eq(2)
    })

    it("refund", async () => {
        let amount = web3.utils.hexToBytes("0x00000000000000000000000000000000000000000000000000000000000003e8")
        let account = (await accounts[0].getAddress()).toString()
        let erc20PacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sender: agent.address.toLocaleLowerCase(),
            receiver: account.toLocaleLowerCase(),
            amount: amount,
            token: erc20.address.toLocaleLowerCase(),
            oriToken: "0x0000000000000000000000000000000010000011"
        }

        let erc20PacketDataBz = client.TokenTransfer.encode(erc20PacketData).finish()

        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let sequence: BigNumber = BigNumber.from(1)
        let pac = {
            sequence: sequence,
            sourceChain: srcChainName,
            destChain: destChainName,
            relayChain: "",
            ports: ["FT"],
            dataList: [erc20PacketDataBz],
        }
        let path = "commitments/" + pac.sourceChain + "/" + pac.destChain + "/sequences/" + pac.sequence
        expect(await mockPacket.commitments(Buffer.from(path, "utf-8"))).to.eq(sha256(sha256(erc20PacketDataBz)))
        console.log()
        expect(await erc20.balanceOf(agent.address.toLowerCase().toString())).to.eq("1047576")
        let Erc20Ack = await mockTransfer.NewAcknowledgement(false, "1: onRecvPackt: binding is not exist")

        await mockPacket.acknowledgePacket(pac, Erc20Ack, proof, height)
        expect(await mockPacket.getAckStatus(srcChainName, destChainName, 1)).to.eq(2)

        await agent.refund(srcChainName, destChainName, 1)
        expect(await erc20.balanceOf(agent.address.toLowerCase().toString())).to.eq("1048576")
        expect(await agent.balances(account.toLowerCase(), erc20.address.toLowerCase())).to.eq("1048576")
        expect(await agent.supplies(erc20.address.toLowerCase())).to.eq("1048576")
        expect(await agent.refunded(srcChainName + "/" + destChainName + "/" + "1")).to.eq(true)
    })

    const deployMockTransfer = async () => {
        const transferFactory = await ethers.getContractFactory('MockTransfer', accounts[0])
        mockTransfer = await upgrades.deployProxy(
            transferFactory,
            [
                mockPacket.address,
                clientManager.address,
                accessManager.address
            ]
        ) as MockTransfer
        await routing.addRouting("FT", mockTransfer.address)
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

    const deployAgent = async () => {
        const AgentFactory = await ethers.getContractFactory('Agent')
        agent = await upgrades.deployProxy(
            AgentFactory,
            [
                mockTransfer.address,
                rcc.address,
                mockPacket.address,
            ]
        ) as Agent
    }

    const createClient = async function (chainName: string, lightClientAddress: any, clientState: any, consensusState: any) {
        let clientStateBuf = client.ClientState.encode(clientState).finish()
        let consensusStateBuf = client.ConsensusState.encode(consensusState).finish()
        await clientManager.createClient(chainName, lightClientAddress, clientStateBuf, consensusStateBuf)
    }

    const deployAccessManager = async () => {
        const accessFactory = await ethers.getContractFactory('AccessManager')
        accessManager = (await upgrades.deployProxy(accessFactory, [await accounts[0].getAddress()])) as AccessManager
    }

    const deployClientManager = async () => {
        const msrFactory = await ethers.getContractFactory('ClientManager', accounts[0])
        clientManager = (await upgrades.deployProxy(msrFactory, [srcChainName, accessManager.address])) as ClientManager
    }

    const deployToken = async () => {
        const tokenFac = await ethers.getContractFactory("testToken")
        erc20 = await tokenFac.deploy("test", "test")
        await erc20.deployed()
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