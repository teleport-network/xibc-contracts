import { BigNumber, Signer } from "ethers"
import chai from "chai"
import { RCC, Routing, ClientManager, Tendermint, Transfer, AccessManager, ERC20, MockPacket } from '../typechain'
import { sha256 } from "ethers/lib/utils"

const { ethers, upgrades } = require("hardhat")
const { expect } = chai

let client = require("./proto/compiled.js")

describe('RCC', () => {
    let rcc: RCC
    let accounts: Signer[]
    let mockPacket: MockPacket
    let transfer: Transfer
    let clientManager: ClientManager
    let routing: Routing
    let tendermint: Tendermint
    let accessManager: AccessManager
    let erc20: ERC20
    let chainName = "teleport"
    const srcChainName = "ethereum"
    const destChainName = "ethereumdest"
    const relayChainName = ""

    before('deploy RCC', async () => {
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
        await initialize()
    })

    it("sendRemoteContractCall", async () => {
        let dataByte = Buffer.from("testdata", "utf-8")
        let rccData = {
            contractAddress: transfer.address,
            data: dataByte,
            destChain: chainName,
            relayChain: relayChainName,
        }
        let sourceChain = await clientManager.getChainName();
        let packetData = {
            srcChain: sourceChain,
            destChain: rccData.destChain,
            sender: (await accounts[0].getAddress()).toString().toLowerCase(),
            contractAddress: rccData.contractAddress,
            data: rccData.data,
        }
        let dataBytes = await client.RemoteContractCall.encode(packetData).finish()

        await rcc.sendRemoteContractCall(rccData)
        let path = "commitments/" + srcChainName + "/" + rccData.destChain + "/sequences/" + 1
        let commit = await mockPacket.commitments(Buffer.from(path, "utf-8"))
        let seq = await mockPacket.getNextSequenceSend(srcChainName, chainName)
        expect(seq).to.equal(2)
        expect(commit).to.equal(sha256(sha256(dataBytes)))
    })

    it("onRecvPacket", async () => {
        let account = (await accounts[0].getAddress()).toString()
        // approve to rcc.address 
        let dataByte = Buffer.from("095ea7b3000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb922660000000000000000000000000000000000000000000000000000000000000001", "hex")
        let sourceChain = await clientManager.getChainName();
        let packetData = {
            srcChain: sourceChain,
            destChain: chainName,
            sender: account.toLowerCase(),
            contractAddress: erc20.address,
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
            ports: ["CONTRACT"],
            dataList: [transferByte],
        }
        await mockPacket.recvPacket(pac, proof, height)
        let allowances = (await erc20.allowance(rcc.address, account))
        expect(allowances.toString()).to.equal("1")
    })

    const deployMockPacket = async () => {
        const mockPacketFactory = await ethers.getContractFactory(
            'MockPacketUpgrade',
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
        clientManager = (await upgrades.deployProxy(msrFactory, ["ethereum", accessManager.address])) as ClientManager
    }

    const deployToken = async () => {
        const tokenFac = await ethers.getContractFactory("testToken")
        erc20 = await tokenFac.deploy("Testcoin", "abiton")
        await erc20.deployed()

        erc20.mint(await accounts[0].getAddress(), 1000)
        erc20.approve(transfer.address, 10000)
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

    const deployTendermint = async () => {
        let originChainName = await clientManager.getChainName()
        expect(originChainName).to.eq("ethereum")

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

        await createClient(chainName, tendermint.address, clientState, consensusState)

        let teleportClient = await clientManager.clients(chainName)
        expect(teleportClient).to.eq(tendermint.address)

        let latestHeight = await clientManager.getLatestHeight(chainName)
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
        let ret1 = await clientManager.registerRelayer(chainName, signer)
        expect(ret1.blockNumber).to.greaterThan(0)
    }
})