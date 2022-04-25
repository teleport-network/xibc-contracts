import { BigNumber, utils, Signer } from "ethers"
import chai from "chai"
import { RCC, Routing, ClientManager, Tendermint, MockTransfer, AccessManager, MockPacket, ERC20, MultiCall } from '../typechain'
import { sha256, keccak256 } from "ethers/lib/utils"
import { web3 } from "hardhat"
const { ethers, upgrades } = require("hardhat")
const { expect } = chai

let client = require("./proto/compiled.js")

describe('MultiCall', () => {
    let rcc: RCC
    let accounts: Signer[]
    let mockPacket: MockPacket
    let clientManager: ClientManager
    let routing: Routing
    let tendermint: Tendermint
    let accessManager: AccessManager
    let mockTransfer: MockTransfer
    let multiCall: MultiCall
    let erc20: ERC20
    let chainName = "teleport"
    const srcChainName = "ethereum"

    before('deploy Multicall', async () => {
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
        await deployMultiCall()
        await initialize()
    })

    it("multiCall", async () => {
        erc20.mint(await accounts[0].getAddress(), 1000)
        await erc20.approve(multiCall.address, 100000)
        expect((await erc20.balanceOf(await accounts[0].getAddress())).toString()).to.eq("1000")

        let account = await accounts[0].getAddress()
        let balances = (await erc20.balanceOf(await accounts[0].getAddress())).toString()
        expect(balances.toString()).to.eq("1000")
        let ERC20TransferData = {
            tokenAddress: erc20.address.toLocaleLowerCase(),
            receiver: (await accounts[1].getAddress()).toString().toLocaleLowerCase(),
            amount: 1,
        }
        let ERC20TransferDataAbi = utils.defaultAbiCoder.encode(["tuple(address,string,uint256)"], [[ERC20TransferData.tokenAddress, ERC20TransferData.receiver, ERC20TransferData.amount]]);
        let BaseTransferData = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            receiver: (await accounts[1].getAddress()).toString().toLocaleLowerCase(),
            amount: 1,
        }
        let BaseTransferDataAbi = utils.defaultAbiCoder.encode(["tuple(address,string,uint256)"], [[BaseTransferData.tokenAddress, BaseTransferData.receiver, BaseTransferData.amount]]);
        let dataByte = Buffer.from("095ea7b3000000000000000000000000f5059a5d33d5853360d16c683c16e67980206f360000000000000000000000000000000000000000000000000000000000000001", "hex")
        let RCCData = {
            contractAddress: erc20.address.toString().toLocaleLowerCase(),
            data: dataByte,
        }
        let RCCDataAbi = utils.defaultAbiCoder.encode(["tuple(string,bytes)"], [[RCCData.contractAddress, RCCData.data]]);

        let role = Buffer.from("MULTISEND_ROLE", "utf-8")
        expect((await accessManager.hasRole(keccak256(role), account.toString())).toString()).to.eq("true")
        expect((await accessManager.hasRole(keccak256(role), multiCall.address.toString())).toString()).to.eq("true")

        let MultiCallData = {
            destChain: chainName,
            relayChain: "",
            functions: [BigNumber.from(0), BigNumber.from(0), BigNumber.from(1)],
            data: [ERC20TransferDataAbi, BaseTransferDataAbi, RCCDataAbi],
        }
        let Fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }
        await multiCall.multiCall(
            MultiCallData,
            Fee,
            { value: BaseTransferData.amount }
        )
        balances = (await erc20.balanceOf(account)).toString()
        expect(balances).to.eq("999")
        let outToken = (await mockTransfer.outTokens("0x0000000000000000000000000000000000000000", chainName))
        expect(outToken.toString()).to.eq(BaseTransferData.amount.toString())
        let Erc20outToken = (await mockTransfer.outTokens(erc20.address, chainName))
        expect(Erc20outToken.toString()).to.eq("1")

        let path = "commitments/" + srcChainName + "/" + chainName + "/sequences/" + 1
        let commitment = await mockPacket.commitments(Buffer.from(path, "utf-8"))
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")

        let ERC20TransferPacketData = {
            srcChain: srcChainName.toString().toLocaleLowerCase(),
            destChain: MultiCallData.destChain.toString().toLocaleLowerCase(),
            sequence: 1,
            sender: account.toString().toLocaleLowerCase(),
            receiver: ERC20TransferData.receiver.toString().toLocaleLowerCase(),
            amount: amount,
            token: ERC20TransferData.tokenAddress.toString().toLocaleLowerCase(),
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

        let BaseTransferPacketData = {
            srcChain: srcChainName,
            destChain: chainName,
            sequence: 1,
            sender: account.toLocaleLowerCase(),
            receiver: BaseTransferData.receiver,
            amount: amount,
            token: "0x0000000000000000000000000000000000000000",
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
        portBytes = Buffer.from("FT", "utf-8")
        packetDataBytes = Buffer.from(web3.utils.hexToBytes(BaseTransferPacketDataBz))
        lengthSum = portBytes.length + packetDataBytes.length
        sum = Buffer.concat([portBytes, packetDataBytes], lengthSum)
        let BaseTransferPacketDataBzHash = Buffer.from(web3.utils.hexToBytes(sha256(sum)))

        let RccPacket = {
            srcChain: srcChainName,
            destChain: chainName,
            sequence: 1,
            sender: account.toLocaleLowerCase(),
            contractAddress: RCCData.contractAddress,
            data: RCCData.data
        }
        let RccPacketDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes)"],
            [
                [
                    RccPacket.srcChain,
                    RccPacket.destChain,
                    RccPacket.sequence,
                    RccPacket.sender,
                    RccPacket.contractAddress,
                    RccPacket.data,
                ]
            ]
        );
        portBytes = Buffer.from("CONTRACT", "utf-8")
        packetDataBytes = Buffer.from(web3.utils.hexToBytes(RccPacketDataBz))
        lengthSum = portBytes.length + packetDataBytes.length
        sum = Buffer.concat([portBytes, packetDataBytes], lengthSum)
        let RccPacketDataBzHash = Buffer.from(web3.utils.hexToBytes(sha256(sum)))
        lengthSum = ERC20TransferPacketDataBzHash.length + BaseTransferPacketDataBzHash.length + RccPacketDataBzHash.length
        sum = Buffer.concat([ERC20TransferPacketDataBzHash, BaseTransferPacketDataBzHash, RccPacketDataBzHash], lengthSum)
        expect(commitment.toString()).to.eq(sha256(sum))
    })

    it("onRecvPacket_vx", async () => {
        let account = await accounts[0].getAddress()
        let balances = (await erc20.balanceOf(await accounts[0].getAddress())).toString()
        expect(balances.toString()).to.eq("999")

        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let sequenceUint64 = 1
        let ERC20TransferPacket = {
            srcChain: "",
            destChain: "",
            sequence: sequenceUint64,
            sender: "",
            receiver: (await accounts[1].getAddress()).toLocaleLowerCase(),
            amount: amount,
            token: "0x0000000000000000000000000000000100000000",
            oriToken: ""
        }
        let ERC20TransferPacketData = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    ERC20TransferPacket.srcChain,
                    ERC20TransferPacket.destChain,
                    ERC20TransferPacket.sequence,
                    ERC20TransferPacket.sender,
                    ERC20TransferPacket.receiver,
                    ERC20TransferPacket.amount,
                    ERC20TransferPacket.token,
                    ERC20TransferPacket.oriToken
                ]
            ]
        );
        let dataByte = Buffer.from("095ea7b3000000000000000000000000f5059a5d33d5853360d16c683c16e67980206f360000000000000000000000000000000000000000000000000000000000000001", "hex")
        let RCCData = {
            contractAddress: erc20.address.toString().toLocaleLowerCase(),
            data: dataByte,
        }
        let RccPacket = {
            srcChain: "",
            destChain: "",
            sequence: sequenceUint64,
            sender: account.toLocaleLowerCase(),
            contractAddress: RCCData.contractAddress,
            data: RCCData.data
        }
        let RccPacketData = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes)"],
            [
                [
                    RccPacket.srcChain,
                    RccPacket.destChain,
                    RccPacket.sequence,
                    RccPacket.sender,
                    RccPacket.contractAddress,
                    RccPacket.data,
                ]
            ]
        );
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let sequence: BigNumber = BigNumber.from(1)
        let muticallPacket = {
            sequence: sequence,
            sourceChain: chainName,
            destChain: srcChainName,
            relayChain: "",
            ports: ["CONTRACT", "FT"],
            dataList: [RccPacketData, ERC20TransferPacketData],
        }
        await mockPacket.recvPacket(muticallPacket, proof, height)
        balances = (await erc20.balanceOf(account)).toString()
        expect(balances).to.eq("999")
        let outToken = (await mockTransfer.outTokens("0x0000000000000000000000000000000000000000", chainName))
        expect(outToken.toString()).to.eq("1")
        let ERC20Ack = utils.defaultAbiCoder.encode(
            ["tuple(bytes[],string,string)"],
            [
                [
                    [],
                    "1: onRecvPackt: binding is not exist",
                    account.toLocaleLowerCase()
                ]
            ]
        );
        let key = "acks/" + muticallPacket.sourceChain + "/" + muticallPacket.destChain + "/sequences/" + muticallPacket.sequence
        let ackCommit = await mockPacket.commitments(Buffer.from(key, "utf-8"))
        expect(ackCommit).to.equal(sha256(ERC20Ack))
    })

    it("onRecvPacket_vv", async () => {
        let account = await accounts[0].getAddress()
        let balances = (await erc20.balanceOf(await accounts[0].getAddress())).toString()
        expect(balances.toString()).to.eq("999")

        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")

        let outToken = (await mockTransfer.outTokens("0x0000000000000000000000000000000000000000", chainName))
        expect(outToken.toString()).to.eq("1")
        let sequenceUint64 = 2
        let BaseTransferPacket = {
            srcChain: chainName,
            destChain: srcChainName,
            sequence: sequenceUint64,
            sender: "",
            receiver: (await accounts[1].getAddress()).toLocaleLowerCase(),
            amount: amount,
            token: "",
            oriToken: erc20.address.toLowerCase()
        }
        let BaseTransferPacketData = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes,string,string)"],
            [
                [
                    BaseTransferPacket.srcChain,
                    BaseTransferPacket.destChain,
                    BaseTransferPacket.sequence,
                    BaseTransferPacket.sender,
                    BaseTransferPacket.receiver,
                    BaseTransferPacket.amount,
                    BaseTransferPacket.token,
                    BaseTransferPacket.oriToken
                ]
            ]
        );

        let dataByte = Buffer.from("095ea7b3000000000000000000000000f5059a5d33d5853360d16c683c16e67980206f360000000000000000000000000000000000000000000000000000000000000001", "hex")
        let RCCData = {
            contractAddress: erc20.address.toString().toLocaleLowerCase(),
            data: dataByte,
        }
        let RccPacket = {
            srcChain: "",
            destChain: "",
            sequence: sequenceUint64,
            sender: account.toLocaleLowerCase(),
            contractAddress: RCCData.contractAddress,
            data: RCCData.data
        }
        let RccPacketData = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,string,bytes)"],
            [
                [
                    RccPacket.srcChain,
                    RccPacket.destChain,
                    RccPacket.sequence,
                    RccPacket.sender,
                    RccPacket.contractAddress,
                    RccPacket.data,
                ]
            ]
        );
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let sequence: BigNumber = BigNumber.from(2)
        let muticallPacket = {
            sequence: sequence,
            sourceChain: chainName,
            destChain: srcChainName,
            relayChain: "",
            ports: ["CONTRACT", "FT"],
            dataList: [RccPacketData, BaseTransferPacketData],
        }
        await mockPacket.recvPacket(muticallPacket, proof, height)
        balances = (await erc20.balanceOf(account)).toString()
        expect(balances).to.eq("999")
        let Erc20outToken = (await mockTransfer.outTokens(erc20.address, chainName))
        expect(Erc20outToken.toString()).to.eq("0")

        let index1 = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let index2 = web3.utils.hexToBytes("0x01")
        let Data = {
            results: [index1, index2],
            message: "",
            relayer: account.toLocaleLowerCase(),
        }
        let key = "acks/" + muticallPacket.sourceChain + "/" + muticallPacket.destChain + "/sequences/" + muticallPacket.sequence
        let ackCommit = await mockPacket.commitments(Buffer.from(key, "utf-8"))
        let Ack = utils.defaultAbiCoder.encode(
            ["tuple(bytes[],string,string)"],
            [
                [
                    Data.results,
                    Data.message,
                    Data.relayer,
                ]
            ]
        );
        expect(ackCommit).to.equal(sha256(Ack))
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

    const deployMultiCall = async () => {
        const multiCallFactory = await ethers.getContractFactory('MultiCall')
        multiCall = await upgrades.deployProxy(
            multiCallFactory,
            [
                mockPacket.address,
                clientManager.address,
                mockTransfer.address,
                rcc.address,
            ]
        ) as MultiCall
        let role = Buffer.from("MULTISEND_ROLE", "utf-8")
        await accessManager.grantRole(keccak256(role), multiCall.address)
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

        const LightClientVerify = await ethers.getContractFactory('LightClientVerify')
        const lightClientVerify = await LightClientVerify.deploy()
        await lightClientVerify.deployed()

        const LightClientGenValHash = await ethers.getContractFactory('LightClientGenValHash')
        const lightClientGenValHash = await LightClientGenValHash.deploy()
        await lightClientGenValHash.deployed()

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
                    LightClientVerify: lightClientVerify.address,
                    LightClientGenValHash: lightClientGenValHash.address,
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