import { Signer, BigNumber, utils } from "ethers"
import chai from "chai"
import { EndpointAC, Execute, PacketAC, ClientManagerAC, MockTendermint, AccessManager, ERC20 } from '../typechain'
import { web3 } from "hardhat"

const { expect } = chai
const { ethers, upgrades } = require("hardhat")
const keccak256 = require('keccak256')

let client = require("./proto/compiled.js")

describe('Endpoint', () => {
    let accounts: Signer[]
    let endpoint: EndpointAC
    let execute: Execute
    let packetContract: PacketAC
    let clientManager: ClientManagerAC
    let tendermint: MockTendermint
    let accessManager: AccessManager
    let erc20Contract: ERC20

    const chainName = "chainName"
    const testChainName = "testChainName"

    before('deploy Endpoint', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await deployPacket()
        await deployEndpoint()
        await deployExecute()
        await deployToken()
    })

    it("bind token", async () => {
        let address0 = "0x0000000000000000000000000000000000000000"
        let tokenAddress = "0x1000000000000000000000000000000010000000"
        let bindDstChain = "test"
        let reBindDstChain = "retest"

        let bindOriToken = "testbind"
        let reBindOriToken = "testrebind"

        await endpoint.bindToken(tokenAddress, bindOriToken, bindDstChain)
        let bind = await endpoint.getBindings(tokenAddress)
        expect(bind.bound).to.eq(true)
        expect(bind.oriChain).to.eq(bindDstChain)
        expect(bind.oriToken).to.eq(bindOriToken)

        await endpoint.bindToken(tokenAddress, reBindOriToken, bindDstChain)
        bind = await endpoint.getBindings(tokenAddress)
        expect(bind.bound).to.eq(true)
        expect(bind.oriChain).to.eq(bindDstChain)
        expect(bind.oriToken).to.eq(reBindOriToken)
        let reBindKey = bindDstChain + "/" + bindOriToken
        expect(await endpoint.bindingTraces(reBindKey)).to.eq(address0)

        await endpoint.bindToken(tokenAddress, reBindOriToken, reBindDstChain)
        bind = await endpoint.getBindings(tokenAddress)
        expect(bind.bound).to.eq(true)
        expect(bind.oriChain).to.eq(reBindDstChain)
        expect(bind.oriToken).to.eq(reBindOriToken)
        reBindKey = bindDstChain + "/" + reBindOriToken
        expect(await endpoint.bindingTraces(reBindKey)).to.eq(address0)

        await endpoint.bindToken(tokenAddress, bindOriToken, bindDstChain)
        bind = await endpoint.getBindings(tokenAddress)
        expect(bind.bound).to.eq(true)
        expect(bind.oriChain).to.eq(bindDstChain)
        expect(bind.oriToken).to.eq(bindOriToken)
        reBindKey = reBindDstChain + "/" + reBindOriToken
        expect(await endpoint.bindingTraces(reBindKey)).to.eq(address0)

    })

    it("test transfer ERC20", async () => {
        let balances = (await erc20Contract.balanceOf(await accounts[0].getAddress())).toString()
        expect(balances.toString()).to.eq("10000000000000")

        let crossChainData = {
            dstChain: testChainName,
            tokenAddress: erc20Contract.address.toLocaleLowerCase(),
            receiver: (await accounts[1].getAddress()),
            amount: 1,
            contractAddress: endpoint.address.toLocaleLowerCase(),
            callData: Buffer.from("testdata", "utf-8"),
            callbackAddress: "0x0000000000000000000000000000000000000000",
            feeOption: 0,
        }
        let Fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }

        await endpoint.crossChainCall(crossChainData, Fee)
        let outToken = (await endpoint.outTokens(erc20Contract.address, testChainName))
        balances = (await erc20Contract.balanceOf(await accounts[0].getAddress())).toString()
        expect(outToken).to.eq(1)
        expect(balances.toString()).to.eq("9999999999999")
    })

    it("test transfer Base token", async () => {
        let crossChainData = {
            dstChain: testChainName,
            tokenAddress: "0x0000000000000000000000000000000000000000",
            receiver: (await accounts[1].getAddress()),
            amount: 10000,
            contractAddress: "",
            callData: [],
            callbackAddress: "0x0000000000000000000000000000000000000000",
            feeOption: 0,
        }
        let Fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }
        await endpoint.crossChainCall(
            crossChainData,
            Fee,
            { value: 10000 }
        )

        let outToken = (await endpoint.outTokens("0x0000000000000000000000000000000000000000", testChainName))
        expect(outToken.toString()).to.eq("10000")
    })

    it("test receive ERC20", async () => {
        let account = (await accounts[2].getAddress()).toLocaleLowerCase()
        let receiver = (await accounts[0].getAddress()).toLocaleLowerCase()
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let sequ64 = 1


        let transferData = {
            token: erc20Contract.address.toLocaleLowerCase(),
            oriToken: erc20Contract.address.toLocaleLowerCase(),
            amount: amount,
            receiver: receiver,
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
        let callData = {
            contractAddress: erc20Contract.address.toLocaleLowerCase(),
            callData: Buffer.from("095ea7b3000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb922660000000000000000000000000000000000000000000000000000000000000001", "hex"),
        }
        let callDataBz = utils.defaultAbiCoder.encode(
            ["tuple(string,bytes)"],
            [[
                callData.contractAddress,
                callData.callData,
            ]]
        )
        let packet = {
            srcChain: testChainName,
            dstChain: chainName,
            sequence: sequ64,
            sender: account,
            transferData: Buffer.from(web3.utils.hexToBytes(transferDataBz)),
            callData: Buffer.from(web3.utils.hexToBytes(callDataBz)),
            callbackAddress: "0x0000000000000000000000000000000000000000",
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

        await packetContract.recvPacket(packetBytes, proof, height)
        let outToken = (await endpoint.outTokens(erc20Contract.address, testChainName))
        let balances = (await erc20Contract.balanceOf(await accounts[0].getAddress())).toString()
        expect(outToken).to.eq(0)
        expect(balances.toString()).to.eq("10000000000000")

        let allowances = (await erc20Contract.allowance(execute.address, "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"))
        expect(allowances.toString()).to.equal("1")
    })

    it("test receive base token", async () => {
        let account = (await accounts[2].getAddress()).toLocaleLowerCase()
        let receiver = (await accounts[3].getAddress()).toLocaleLowerCase()
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let sequ64 = 2

        let transferData = {
            token: erc20Contract.address.toLocaleLowerCase(),
            oriToken: "0x0000000000000000000000000000000000000000",
            amount: amount,
            receiver: receiver,
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
            dstChain: chainName,
            sequence: sequ64,
            sender: account,
            transferData: Buffer.from(web3.utils.hexToBytes(transferDataBz)),
            callData: [],
            callbackAddress: "0x0000000000000000000000000000000000000000",
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

        let balances = await web3.eth.getBalance(transferData.receiver)
        expect(balances).to.eq("10000000000000000000000")
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }

        await packetContract.recvPacket(packetBytes, proof, height)
        balances = await web3.eth.getBalance(transferData.receiver)
        expect(balances).to.eq("10000000000000000000001")
    })

    it("upgrade endpoint", async () => {
        // upgrade Endpoint contract and check the contract address    
        const mockEndpointFactory = await ethers.getContractFactory("MockEndpoint")
        const upgradedEndpoint = await upgrades.upgradeProxy(endpoint.address, mockEndpointFactory)
        expect(upgradedEndpoint.address).to.eq(endpoint.address)

        // verify that old data can be accessed
        let outToken = (await upgradedEndpoint.outTokens("0x0000000000000000000000000000000000000000", testChainName))
        expect(outToken.toString()).to.eq("9999")

        // verify new func in upgradeTransfer 
        await upgradedEndpoint.setVersion(1)
        const version = await upgradedEndpoint.version()
        expect(1).to.eq(version.toNumber())

        // the old method of verifying that has been changed
        let account = (await accounts[2].getAddress()).toLocaleLowerCase()
        let receiver = (await accounts[1].getAddress()).toLocaleLowerCase()
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let seqU64 = 2

        let transferData = {
            token: erc20Contract.address.toLocaleLowerCase(),
            oriToken: "",
            amount: amount,
            receiver: receiver,
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
            dstChain: chainName,
            sequence: seqU64,
            sender: account,
            transferData: Buffer.from(web3.utils.hexToBytes(transferDataBz)),
            callData: [],
            callbackAddress: "0x0000000000000000000000000000000000000000",
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

        await endpoint.bindToken(erc20Contract.address, transferData.token, packet.srcChain)
        let trace = await endpoint.bindingTraces(packet.srcChain + "/" + transferData.token)
        expect(trace.toString()).to.eq(erc20Contract.address)

        await upgradedEndpoint.onRecvPacket(packet)
        let balances = (await erc20Contract.balanceOf(receiver)).toString()
        let binds = await upgradedEndpoint.bindings(erc20Contract.address)
        let totalSupply = (await erc20Contract.totalSupply()).toString()

        expect(binds.amount.toString()).to.eq("1")
        expect(totalSupply).to.eq("10000000000001")
        expect(balances).to.eq("1")
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
        let teleportClient = await clientManager.client()
        expect(teleportClient).to.eq(tendermint.address)

        let latestHeight = await clientManager.getLatestHeight()
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

        let relayerRole = keccak256("RELAYER_ROLE")
        let signer = await accounts[0].getAddress()
        let ret = await accessManager.grantRole(relayerRole, signer)
        expect(ret.blockNumber).to.greaterThan(0)
    }

    const deployToken = async () => {
        const tokenFac = await ethers.getContractFactory("TestToken")
        erc20Contract = await tokenFac.deploy("Testcoin", "abiton")
        await erc20Contract.deployed()
        erc20Contract.mint(await accounts[0].getAddress(), 10000000000000)
        erc20Contract.approve(endpoint.address, 1000000000)
        expect((await erc20Contract.balanceOf(await accounts[0].getAddress())).toString()).to.eq("10000000000000")
    }

    const deployPacket = async () => {
        const packetFactory = await ethers.getContractFactory(
            'contracts/chains/02-evm/core/packet/Packet.sol:Packet',
            { signer: accounts[0], }
        )

        packetContract = await upgrades.deployProxy(
            packetFactory,
            [
                chainName,
                testChainName,
                clientManager.address,
                accessManager.address,
            ]
        ) as Packet
    }

    const deployEndpoint = async () => {
        const endpointFactory = await ethers.getContractFactory(
            'contracts/chains/02-evm/core/endpoint/Endpoint.sol:Endpoint',
            accounts[0]
        )
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
        const executeFactory = await ethers.getContractFactory(
            'contracts/chains/02-evm/core/endpoint/Execute.sol:Execute',
            accounts[0]
        )
        execute = await upgrades.deployProxy(
            executeFactory,
            [packetContract.address]
        ) as Execute

        await packetContract.initEndpoint(endpoint.address, execute.address)
    }
})
