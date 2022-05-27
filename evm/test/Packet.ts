import { Signer, BigNumber, utils } from "ethers"
import { MockCrossChain, Packet, ClientManager, MockTendermint, AccessManager, ERC20 } from '../typechain'
import { sha256 } from "ethers/lib/utils"
import chai from "chai"

const { expect } = chai
const { web3, ethers, upgrades } = require("hardhat")
const keccak256 = require('keccak256')

let client = require("./proto/compiled.js")

describe('Packet', () => {
    let clientManager: ClientManager
    let tendermint: MockTendermint
    let crossChain: MockCrossChain
    let accessManager: AccessManager
    let accounts: Signer[]
    let packetContract: Packet
    let erc20Contract: ERC20

    const chainName = "teleport"
    const testChainName = "testChainName"

    before('deploy Packet', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await deployPacket()
        await deployCrossChain()
        await deployToken()
    })

    it("send packet and receive ack", async () => {
        let account = (await accounts[0].getAddress()).toString()
        let callbackAddress = "0x0000000000000000000000000000000000000000"
        let crossChainData = {
            destChain: testChainName,
            tokenAddress: erc20Contract.address.toLocaleLowerCase(),
            receiver: (await accounts[3].getAddress()).toString().toLocaleLowerCase(),
            amount: 1,
            contractAddress: "",
            callData: [],
            callbackAddress: callbackAddress,
            feeOption: 0,
        }
        let Fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }

        let transferData = {
            token: erc20Contract.address.toLocaleLowerCase(),
            oriToken: "",
            amount: web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001"),
            receiver: (await accounts[3].getAddress()).toString().toLocaleLowerCase(),
        }
        let transferDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,bytes,string)"],
            [[
                transferData.token,
                transferData.oriToken,
                transferData.amount,
                transferData.receiver,
            ]]
        )
        let packet = {
            srcChain: chainName,
            destChain: testChainName,
            sequence: 1,
            sender: (await accounts[0].getAddress()).toString().toLocaleLowerCase(),
            transferData: Buffer.from(web3.utils.hexToBytes(transferDataBz)),
            callData: [],
            callbackAddress: callbackAddress,
            feeOption: 0,
        }
        let packetBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,bytes,bytes,string,uint64)"],
            [[
                packet.srcChain,
                packet.destChain,
                packet.sequence,
                packet.sender,
                packet.transferData,
                packet.callData,
                packet.callbackAddress,
                packet.feeOption,
            ]]
        );
        let path = "commitments/" + chainName + "/" + testChainName + "/sequences/" + 1
        await crossChain.crossChainCall(crossChainData, Fee)
        let commit = await packetContract.commitments(Buffer.from(path, "utf-8"))
        let seq = await packetContract.getNextSequenceSend(testChainName)
        expect(seq).to.equal(2)

        let packetBytes = Buffer.from(web3.utils.hexToBytes(packetBz))
        expect(commit).to.equal(sha256(packetBytes))

        let ackBytes = utils.defaultAbiCoder.encode(
            ["tuple(uint64,bytes,string,string,uint64)"],
            [[0, [], "", account.toLowerCase(), 0]]
        );
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        await packetContract.acknowledgePacket(packetBytes, ackBytes, proof, height)
        commit = await packetContract.commitments(Buffer.from(path, "utf-8"))
        expect(commit).to.equal('0x0000000000000000000000000000000000000000000000000000000000000000')
    })

    it("receive packet and write ack", async () => {
        let account = (await accounts[0].getAddress()).toString()
        let callbackAddress = "0x0000000000000000000000000000000000000000"

        let transferData = {
            token: "0x0000000000000000000000000000000000000000",
            oriToken: erc20Contract.address.toLocaleLowerCase(),
            amount: web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001"),
            receiver: (await accounts[0].getAddress()).toString().toLocaleLowerCase(),
        }
        let transferDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,bytes,string)"],
            [[
                transferData.token,
                transferData.oriToken,
                transferData.amount,
                transferData.receiver,
            ]]
        )
        let packet = {
            srcChain: testChainName,
            destChain: chainName,
            sequence: 1,
            sender: (await accounts[3].getAddress()).toString().toLocaleLowerCase(),
            transferData: Buffer.from(web3.utils.hexToBytes(transferDataBz)),
            callData: [],
            callbackAddress: callbackAddress,
            feeOption: 0,
        }
        let packetBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,bytes,bytes,string,uint64)"],
            [[
                packet.srcChain,
                packet.destChain,
                packet.sequence,
                packet.sender,
                packet.transferData,
                packet.callData,
                packet.callbackAddress,
                packet.feeOption,
            ]]
        );
        let packetBytes = Buffer.from(web3.utils.hexToBytes(packetBz))
        let ackBz = utils.defaultAbiCoder.encode(
            ["tuple(uint64,bytes,string,string,uint64)"],
            [[0, [], "", account.toLowerCase(), 0]]
        );
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        await packetContract.recvPacket(packetBytes, proof, height)
        let ackPath = "acks/" + testChainName + "/" + chainName + "/sequences/" + 1
        let receiptPath = testChainName + "/" + 1
        expect(await packetContract.receipts(Buffer.from(receiptPath, "utf-8"))).to.equal(true)
        let ackCommit = await packetContract.commitments(Buffer.from(ackPath, "utf-8"))
        expect(ackCommit).to.equal(sha256(Buffer.from(web3.utils.hexToBytes(ackBz))))
    })

    it("upgrade packet", async () => {
        const mockPacketFactory = await ethers.getContractFactory("MockPacket")
        const mockPacket = await upgrades.upgradeProxy(packetContract.address, mockPacketFactory)
        expect(mockPacket.address).to.eq(packetContract.address)

        await mockPacket.setVersion(2)
        const version = await mockPacket.version()
        expect(2).to.eq(version.toNumber())
    })

    const deployAccessManager = async () => {
        const accessFactory = await ethers.getContractFactory('AccessManager')
        accessManager = (await upgrades.deployProxy(accessFactory, [await accounts[0].getAddress()])) as AccessManager

        let relayerRole = keccak256("RELAYER_ROLE")
        let signer = await accounts[0].getAddress()
        let ret = await accessManager.grantRole(relayerRole, signer)
        expect(ret.blockNumber).to.greaterThan(0)
    }

    const deployClientManager = async () => {
        const msrFactory = await ethers.getContractFactory('ClientManager', accounts[0])
        clientManager = (await upgrades.deployProxy(msrFactory, [accessManager.address])) as ClientManager
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
            chainId: testChainName,
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
        await clientManager.createClient(tendermint.address, clientStateBuf, consensusStateBuf)
    }

    const deployToken = async () => {
        const tokenFactory = await ethers.getContractFactory("TestToken")
        erc20Contract = await tokenFactory.deploy("test", "test")
        await erc20Contract.deployed()

        erc20Contract.mint(await accounts[0].getAddress(), 1000)
        erc20Contract.approve(crossChain.address, 100000)
        expect((await erc20Contract.balanceOf(await accounts[0].getAddress())).toString()).to.eq("1000")
    }

    const deployPacket = async () => {
        const packetFactory = await ethers.getContractFactory(
            'Packet',
            { signer: accounts[0], }
        )

        packetContract = await upgrades.deployProxy(
            packetFactory,
            [
                chainName,
                clientManager.address,
                accessManager.address,
            ]
        ) as Packet
    }

    const deployCrossChain = async () => {
        const crossChainFactory = await ethers.getContractFactory('MockCrossChain', accounts[0])
        crossChain = await upgrades.deployProxy(
            crossChainFactory,
            [
                packetContract.address,
                clientManager.address,
                accessManager.address
            ]
        ) as MockCrossChain

        // init crossChain address after crossChain deployed
        await packetContract.initCrossChain(crossChain.address,)
    }
})