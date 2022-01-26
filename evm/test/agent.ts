import { BigNumber, utils, Signer } from "ethers"
import chai from "chai"
import { RCC, Routing, ClientManager, Tendermint, MockTransfer, AccessManager, MockPacket, ERC20, Agent } from '../typechain'
import { web3 } from "hardhat"
const { ethers, upgrades } = require("hardhat")
const { expect } = chai

let client = require("./proto/compiled.js")

describe('Agent', () => {
    let rcc: RCC
    let accounts: Signer[]
    let mockPacket: MockPacket
    let clientManager: ClientManager
    let routing: Routing
    let tendermint: Tendermint
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
        await initialize()
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
            token: erc20.address.toLocaleLowerCase(),
            oriToken: null
        }
        let erc20PacketDataBz = client.TokenTransfer.encode(erc20PacketData).finish()

        let dataByte = Buffer.from("efb50925000000000000000000000000000000000000000000000000000000000000002000000000000000000000000067d269191c92caf3cd7723f116c85e6e9bf5593300000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000002a30783730393937393730633531383132646333613031306337643031623530653064313764633739633800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000964657374436861696e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "hex")
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

    })
    // todo recvErrAck and refund test
    // await agent.refund(srcChainName,destChainName,1)
    
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

        await erc20.mint(await accounts[0].getAddress(), 1000)
        await erc20.approve(mockTransfer.address, 100000)
        expect((await erc20.balanceOf(await accounts[0].getAddress())).toString()).to.eq("1000")
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
        let originChainName = await clientManager.getChainName()
        expect(originChainName).to.eq(srcChainName)

        const ClientStateCodec = await ethers.getContractFactory('ClientStateCodec')
        const clientStateCodec = await ClientStateCodec.deploy()
        await clientStateCodec.deployed()

        const ConsensusStateCodec = await ethers.getContractFactory('ConsensusStateCodec')
        const consensusStateCodec = await ConsensusStateCodec.deploy()
        await consensusStateCodec.deployed()

        const HeaderCodec = await ethers.getContractFactory('HeaderCodec')
        const headerCodec = await HeaderCodec.deploy()
        await headerCodec.deployed()

        const ProofCodec = await ethers.getContractFactory('ProofCodec')
        const proofCodec = await ProofCodec.deploy()
        await proofCodec.deployed()

        const Verifier = await ethers.getContractFactory(
            'Verifier',
            {
                signer: accounts[0],
                libraries: { ProofCodec: proofCodec.address },
            }
        )
        const verifierLib = await Verifier.deploy()
        await verifierLib.deployed()

        const tmFactory = await ethers.getContractFactory(
            'Tendermint',
            {
                libraries: {
                    ClientStateCodec: clientStateCodec.address,
                    ConsensusStateCodec: consensusStateCodec.address,
                    Verifier: verifierLib.address,
                    HeaderCodec: headerCodec.address,
                },
            }
        )
        tendermint = await upgrades.deployProxy(
            tmFactory,
            [clientManager.address],
            { "unsafeAllowLinkedLibraries": true }
        ) as Tendermint
    }

    const initialize = async () => {
        // create light client
        let clientState = {
            chainId: "teleport",
            trustLevel: { numerator: 1, denominator: 3 },
            trustingPeriod: 1000 * 24 * 60 * 60,
            unbondingPeriod: 1814400,
            maxClockDrift: 10,
            latestHeight: { revisionNumber: 1, revisionHeight: 3893 },
            merklePrefix: { keyPrefix: Buffer.from("xibc"), },
            timeDelay: 10,
        }

        let consensusState = {
            timestamp: { secs: 1631155726, nanos: 5829 },
            root: Buffer.from("gd17k2js3LzwChS4khcRYMwVFWMPQX4TfJ9wG3MP4gs=", "base64"),
            nextValidatorsHash: Buffer.from("B1fwvGc/jfJtYdPnS7YYGsnfiMCaEQDG+t4mRgS0xHg=", "base64")
        }

        await createClient(destChainName, tendermint.address, clientState, consensusState)

        let teleportClient = await clientManager.clients(destChainName)
        expect(teleportClient).to.eq(tendermint.address)

        let latestHeight = await clientManager.getLatestHeight(destChainName)
        expect(latestHeight[0].toNumber()).to.eq(clientState.latestHeight.revisionNumber)
        expect(latestHeight[1].toNumber()).to.eq(clientState.latestHeight.revisionHeight)

        let expClientState = await tendermint.clientState()
        expect(expClientState.chain_id).to.eq(clientState.chainId)

        let key: any = {
            revision_number: clientState.latestHeight.revisionNumber,
            revision_height: clientState.latestHeight.revisionHeight,
        }

        let expConsensusState = await tendermint.getConsensusState(key)
        expect(expConsensusState.root.slice(2)).to.eq(consensusState.root.toString("hex"))
        expect(expConsensusState.next_validators_hash.slice(2)).to.eq(consensusState.nextValidatorsHash.toString("hex"))

        let signer = await accounts[0].getAddress()
        let ret1 = await clientManager.registerRelayer(destChainName, signer)
        expect(ret1.blockNumber).to.greaterThan(0)
    }
})