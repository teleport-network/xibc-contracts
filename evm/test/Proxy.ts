import { Signer, utils } from "ethers"
import chai from "chai"
import { Proxy, Endpoint, Execute, ClientManager, MockTendermint, AccessManager, MockPacket, ERC20 } from '../typechain'
import { web3 } from "hardhat"
import { sha256 } from "ethers/lib/utils"

const { ethers, upgrades } = require("hardhat")
const { expect } = chai
const keccak256 = require('keccak256')

let client = require("./proto/compiled.js")

describe('Proxy', () => {
    let accounts: Signer[]
    let endpoint: Endpoint
    let execute: Execute
    let packetContract: MockPacket
    let clientManager: ClientManager
    let tendermint: MockTendermint
    let accessManager: AccessManager
    let proxy: Proxy
    let erc20Contract: ERC20

    const chainName = "chainName"
    const relayChainName = "relayChainName"
    const testChainName = "testChainName"

    before('deploy Proxy', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await deployMockPacket()
        await deployEndpoint()
        await deployExecute()
        await deployToken()
        await deployProxy()
    })

    it("send ERC20 token", async () => {
        let sender = (await accounts[0].getAddress()).toLocaleLowerCase()
        let receiver = (await accounts[1].getAddress()).toLocaleLowerCase()
        let refundAddress = await accounts[2].getAddress()
        let tokenAddress = erc20Contract.address.toLocaleLowerCase()
        let callbackAddress = "0x0000000000000000000000000000000000000000"

        await erc20Contract.approve(endpoint.address, 2000)
        let allowance = await erc20Contract.allowance(sender, endpoint.address.toLocaleLowerCase())
        expect(allowance.toNumber()).to.eq(2000)

        let agentData = {
            refundAddress: refundAddress,
            dstChain: testChainName,
            tokenAddress: tokenAddress,
            amount: 1000,
            feeAmount: 500,
            receiver: receiver,
            callbackAddress: callbackAddress,
            feeOption: 0,
        }
        let crossChainData = await proxy.genCrossChainData(agentData)
        let fee = {
            tokenAddress: erc20Contract.address,
            amount: 1000,
        }
        await endpoint.crossChainCall(crossChainData, fee)

        let transferData = {
            token: tokenAddress,
            oriToken: "",
            amount: web3.utils.hexToBytes("0x00000000000000000000000000000000000000000000000000000000000003e8"),
            receiver: crossChainData.receiver,
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
        const agentCallDataBz = web3.eth.abi.encodeFunctionCall(
            {
                name: 'send',
                type: 'function',
                inputs: [{
                    "internalType": "address",
                    "name": "refundAddress",
                    "type": "address"
                }, {
                    "internalType": "string",
                    "name": "receiver",
                    "type": "string"
                }, {
                    "internalType": "string",
                    "name": "dstChain",
                    "type": "string"
                }, {
                    "internalType": "uint256",
                    "name": "feeAmount",
                    "type": "uint256"
                }],
            },
            [
                agentData.refundAddress,
                agentData.receiver,
                agentData.dstChain,
                agentData.feeAmount.toString(),
            ]
        )
        expect(crossChainData.callData).to.equal(agentCallDataBz)
        let callData = {
            contractAddress: "0x0000000000000000000000000000000040000001", // agent contract address
            callData: agentCallDataBz,
        }
        let callDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,bytes)"],
            [[
                callData.contractAddress,
                callData.callData,
            ]]
        )
        let packet = {
            srcChain: chainName,
            dstChain: relayChainName,
            sequence: 1,
            sender: sender,
            transferData: Buffer.from(web3.utils.hexToBytes(transferDataBz)),
            callData: Buffer.from(web3.utils.hexToBytes(callDataBz)),
            callbackAddress: callbackAddress,
            feeOption: 0,
        }
        let packetBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,bytes,bytes,string,uint64)"],
            [[
                packet.srcChain,
                packet.dstChain,
                packet.sequence,
                packet.sender,
                packet.transferData,
                packet.callData,
                packet.callbackAddress,
                packet.feeOption,
            ]]
        )
        let packetBytes = Buffer.from(web3.utils.hexToBytes(packetBz))

        let path = "commitments/" + chainName + "/" + relayChainName + "/sequences/" + 1
        let commit = await packetContract.commitments(Buffer.from(path, "utf-8"))
        expect(commit).to.equal(sha256(packetBytes))
        let outToken = await endpoint.outTokens(erc20Contract.address, relayChainName)
        expect(outToken).to.eq(transferData.amount)
    })

    it("send Base token", async () => {
        let sender = (await accounts[0].getAddress()).toLocaleLowerCase()
        let receiver = (await accounts[1].getAddress()).toLocaleLowerCase()
        let refundAddress = await accounts[2].getAddress()
        let baseTokenAddress = "0x0000000000000000000000000000000000000000"
        let callbackAddress = "0x0000000000000000000000000000000000000000"

        let agentData = {
            refundAddress: refundAddress,
            dstChain: testChainName,
            tokenAddress: baseTokenAddress,
            amount: 1000,
            feeAmount: 500,
            receiver: receiver,
            callbackAddress: callbackAddress,
            feeOption: 0,
        }
        let crossChainData = await proxy.genCrossChainData(agentData)
        let fee = {
            tokenAddress: baseTokenAddress,
            amount: 100,
        }
        await endpoint.crossChainCall(crossChainData, fee, { value: agentData.amount + fee.amount })

        let transferData = {
            token: baseTokenAddress,
            oriToken: "",
            amount: web3.utils.hexToBytes("0x00000000000000000000000000000000000000000000000000000000000003e8"),
            receiver: crossChainData.receiver,
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
        const agentCallDataBz = web3.eth.abi.encodeFunctionCall(
            {
                name: 'send',
                type: 'function',
                inputs: [{
                    "internalType": "address",
                    "name": "refundAddress",
                    "type": "address"
                }, {
                    "internalType": "string",
                    "name": "receiver",
                    "type": "string"
                }, {
                    "internalType": "string",
                    "name": "dstChain",
                    "type": "string"
                }, {
                    "internalType": "uint256",
                    "name": "feeAmount",
                    "type": "uint256"
                }],
            },
            [
                agentData.refundAddress,
                agentData.receiver,
                agentData.dstChain,
                agentData.feeAmount.toString(),
            ]
        )
        expect(crossChainData.callData).to.equal(agentCallDataBz)
        let callData = {
            contractAddress: "0x0000000000000000000000000000000040000001", // agent contract address
            callData: agentCallDataBz,
        }
        let callDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,bytes)"],
            [[
                callData.contractAddress,
                callData.callData,
            ]]
        )
        let packet = {
            srcChain: chainName,
            dstChain: relayChainName,
            sequence: 2,
            sender: sender,
            transferData: Buffer.from(web3.utils.hexToBytes(transferDataBz)),
            callData: Buffer.from(web3.utils.hexToBytes(callDataBz)),
            callbackAddress: callbackAddress,
            feeOption: 0,
        }
        let packetBz = utils.defaultAbiCoder.encode(
            ["tuple(string,string,uint64,string,bytes,bytes,string,uint64)"],
            [[
                packet.srcChain,
                packet.dstChain,
                packet.sequence,
                packet.sender,
                packet.transferData,
                packet.callData,
                packet.callbackAddress,
                packet.feeOption,
            ]]
        )
        let packetBytes = Buffer.from(web3.utils.hexToBytes(packetBz))

        let path = "commitments/" + chainName + "/" + relayChainName + "/sequences/" + 2
        let commit = await packetContract.commitments(Buffer.from(path, "utf-8"))
        expect(commit).to.equal(sha256(packetBytes))
        let outToken = await endpoint.outTokens(baseTokenAddress, relayChainName)
        expect(outToken).to.eq(transferData.amount)
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

    const deployMockPacket = async () => {
        const mockPacketFactory = await ethers.getContractFactory(
            'MockPacket',
            { signer: accounts[0], }
        )

        packetContract = await upgrades.deployProxy(
            mockPacketFactory,
            [
                chainName,
                clientManager.address,
                accessManager.address,
            ]
        ) as MockPacket
    }

    const deployEndpoint = async () => {
        const endpointFactory = await ethers.getContractFactory('Endpoint', accounts[0])
        endpoint = await upgrades.deployProxy(
            endpointFactory,
            [
                packetContract.address,
                clientManager.address,
                accessManager.address
            ]
        ) as Endpoint
    }

    const deployExecute = async () => {
        const executeFactory = await ethers.getContractFactory('Execute', accounts[0])
        execute = await upgrades.deployProxy(
            executeFactory,
            [packetContract.address]
        ) as Execute

        await packetContract.initEndpoint(endpoint.address, execute.address)
    }

    const deployProxy = async () => {
        const ProxyFactory = await ethers.getContractFactory('Proxy')
        proxy = await upgrades.deployProxy(
            ProxyFactory,
            [relayChainName]
        ) as Proxy

        await proxy.deployed()
    }

    const deployToken = async () => {
        const tokenFactory = await ethers.getContractFactory("TestToken")
        erc20Contract = await tokenFactory.deploy("test", "test")
        await erc20Contract.deployed()

        erc20Contract.mint(await accounts[0].getAddress(), 1048576)
        expect((await erc20Contract.balanceOf(await accounts[0].getAddress())).toString()).to.eq("1048576")
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
})
