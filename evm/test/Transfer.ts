import { Signer, BigNumber, utils } from "ethers"
import chai from "chai"
import { Transfer, Packet, ClientManager, Routing, MockTendermint, AccessManager, ERC20 } from '../typechain'
import { web3 } from "hardhat"

const { expect } = chai
const { ethers, upgrades } = require("hardhat")

let client = require("./proto/compiled.js")

describe('Transfer', () => {
    let accounts: Signer[]
    let transfer: Transfer
    let packet: Packet
    let clientManager: ClientManager
    let routing: Routing
    let tendermint: MockTendermint
    let accessManager: AccessManager
    let erc20: ERC20
    const srcChainName = "srcChain"
    const destChainName = "dstChain"
    const relayChainName = ""


    before('deploy Transfer', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await deployHost()
        await deployRouting()
        await deployPacket()
        await deployTransfer()
        await deployToken()
    })

    it("bind token", async () => {
        let address0 = "0x0000000000000000000000000000000000000000"
        let tokenAddress = "0x1000000000000000000000000000000010000000"
        let bindDestChain = "test"
        let reBindDestChain = "retest"

        let bindOriToken = "testbind"
        let reBindOriToken = "testrebind"

        await transfer.bindToken(tokenAddress, bindOriToken, bindDestChain)
        let bind = await transfer.getBindings(tokenAddress)
        expect(bind.bound).to.eq(true)
        expect(bind.oriChain).to.eq(bindDestChain)
        expect(bind.oriToken).to.eq(bindOriToken)

        await transfer.bindToken(tokenAddress, reBindOriToken, bindDestChain)
        bind = await transfer.getBindings(tokenAddress)
        expect(bind.bound).to.eq(true)
        expect(bind.oriChain).to.eq(bindDestChain)
        expect(bind.oriToken).to.eq(reBindOriToken)
        let reBindKey = bindDestChain + "/" + bindOriToken
        expect(await transfer.bindingTraces(reBindKey)).to.eq(address0)

        await transfer.bindToken(tokenAddress, reBindOriToken, reBindDestChain)
        bind = await transfer.getBindings(tokenAddress)
        expect(bind.bound).to.eq(true)
        expect(bind.oriChain).to.eq(reBindDestChain)
        expect(bind.oriToken).to.eq(reBindOriToken)
        reBindKey = bindDestChain + "/" + reBindOriToken
        expect(await transfer.bindingTraces(reBindKey)).to.eq(address0)

        await transfer.bindToken(tokenAddress, bindOriToken, bindDestChain)
        bind = await transfer.getBindings(tokenAddress)
        expect(bind.bound).to.eq(true)
        expect(bind.oriChain).to.eq(bindDestChain)
        expect(bind.oriToken).to.eq(bindOriToken)
        reBindKey = reBindDestChain + "/" + reBindOriToken
        expect(await transfer.bindingTraces(reBindKey)).to.eq(address0)

    })

    it("test transfer ERC20", async () => {
        let balances = (await erc20.balanceOf(await accounts[0].getAddress())).toString()
        expect(balances.toString()).to.eq("10000000000000")

        let transferData = {
            tokenAddress: erc20.address,
            receiver: (await accounts[1].getAddress()),
            amount: 1,
            destChain: destChainName,
            relayChain: relayChainName,
        }

        let Fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }

        await transfer.sendTransfer(transferData, Fee)
        let outToken = (await transfer.outTokens(erc20.address, destChainName))
        balances = (await erc20.balanceOf(await accounts[0].getAddress())).toString()
        expect(outToken).to.eq(1)
        expect(balances.toString()).to.eq("9999999999999")
    })

    it("test transfer Base", async () => {
        let transferData = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            receiver: (await accounts[1].getAddress()),
            amount: 10000,
            destChain: destChainName,
            relayChain: "",
        }
        let Fee = {
            tokenAddress: "0x0000000000000000000000000000000000000000",
            amount: 0,
        }
        await transfer.sendTransfer(
            transferData,
            Fee,
            { value: 10000 }
        )

        let outToken = (await transfer.outTokens("0x0000000000000000000000000000000000000000", destChainName))
        expect(outToken.toString()).to.eq("10000")
    })

    it("test receive ERC20 packet", async () => {
        let account = (await accounts[2].getAddress()).toLocaleLowerCase()
        let receiver = (await accounts[0].getAddress()).toLocaleLowerCase()
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let sequ64 = 1
        let packetData = {
            srcChain: destChainName,
            destChain: srcChainName,
            sequence: sequ64,
            sender: account,
            receiver: receiver,
            amount: amount,
            token: erc20.address.toLocaleLowerCase(),
            oriToken: erc20.address.toLocaleLowerCase(),
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
        let sequence: BigNumber = BigNumber.from(1)
        let pac = {
            sequence: sequence,
            sourceChain: destChainName,
            destChain: srcChainName,
            relayChain: relayChainName,
            ports: ["FT"],
            dataList: [packetDataBz],
        }
        await packet.recvPacket(pac, proof, height)

        let outToken = (await transfer.outTokens(erc20.address, destChainName))
        let balances = (await erc20.balanceOf(await accounts[0].getAddress())).toString()
        expect(outToken).to.eq(0)
        expect(balances.toString()).to.eq("10000000000000")
    })

    it("test receive native token packet", async () => {
        let account = (await accounts[2].getAddress()).toLocaleLowerCase()
        let receiver = (await accounts[3].getAddress()).toLocaleLowerCase()
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let sequ64 = 2
        let packetData = {
            srcChain: destChainName,
            destChain: srcChainName,
            sequence: sequ64,
            sender: account,
            receiver: receiver,
            amount: amount,
            token: erc20.address.toLocaleLowerCase(),
            oriToken: "0x0000000000000000000000000000000000000000"
        }

        let transferByte = utils.defaultAbiCoder.encode(
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
        let balances = await web3.eth.getBalance(packetData.receiver)
        expect(balances).to.eq("10000000000000000000000")
        let sequence: BigNumber = BigNumber.from(2)
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let pac = {
            sequence: sequence,
            sourceChain: destChainName,
            destChain: srcChainName,
            relayChain: relayChainName,
            ports: ["FT"],
            dataList: [transferByte],
        }
        await packet.recvPacket(pac, proof, height)

        balances = await web3.eth.getBalance(packetData.receiver)
        expect(balances).to.eq("10000000000000000000001")
    })

    it("upgrade transfer", async () => {
        // upgrade transfer contract and check the contract address    
        const mockTransferFactory = await ethers.getContractFactory("MockTransfer");
        const upgradedTransfer = await upgrades.upgradeProxy(transfer.address, mockTransferFactory);
        expect(upgradedTransfer.address).to.eq(transfer.address);

        // verify that old data can be accessed
        let outToken = (await upgradedTransfer.outTokens("0x0000000000000000000000000000000000000000", destChainName))
        expect(outToken.toString()).to.eq("9999")

        // verify new func in upgradeTransfer 
        await upgradedTransfer.setVersion(1)
        const version = await upgradedTransfer.version();
        expect(1).to.eq(version.toNumber())

        // the old method of verifying that has been changed
        let account = (await accounts[2].getAddress()).toLocaleLowerCase()
        let receiver = (await accounts[1].getAddress()).toLocaleLowerCase()
        let amount = web3.utils.hexToBytes("0x0000000000000000000000000000000000000000000000000000000000000001")
        let seqU64 = 2
        let packetData = {
            srcChain: destChainName,
            destChain: srcChainName,
            sequence: seqU64,
            sender: account,
            receiver: receiver,
            amount: amount,
            token: erc20.address.toLocaleLowerCase(),
            oriToken: ""
        }
        await transfer.bindToken(erc20.address, packetData.token, packetData.srcChain)

        let trace = await transfer.bindingTraces(packetData.srcChain + "/" + packetData.token)
        expect(trace.toString()).to.eq(erc20.address)

        let transferByte = utils.defaultAbiCoder.encode(
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
        await upgradedTransfer.onRecvPacket(transferByte)
        let balances = (await erc20.balanceOf(receiver)).toString()
        let binds = await upgradedTransfer.bindings(erc20.address)
        let totalSupply = (await erc20.totalSupply()).toString()

        expect(binds.amount.toString()).to.eq("1")
        expect(totalSupply).to.eq("10000000000001")
        expect(balances).to.eq("1")
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

    const deployHost = async () => {
        const hostFac = await ethers.getContractFactory("Host")
        const host = await hostFac.deploy()
        await host.deployed()
    }

    const deployToken = async () => {
        const tokenFac = await ethers.getContractFactory("testToken")
        erc20 = await tokenFac.deploy("Testcoin", "abiton")
        await erc20.deployed()
        erc20.mint(await accounts[0].getAddress(), 10000000000000)
        erc20.approve(transfer.address, 1000000000)
        expect((await erc20.balanceOf(await accounts[0].getAddress())).toString()).to.eq("10000000000000")
    }

    const deployRouting = async () => {
        const routingFac = await ethers.getContractFactory("Routing")
        routing = await upgrades.deployProxy(routingFac, [accessManager.address]) as Routing
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
        const transFactory = await ethers.getContractFactory("Transfer")
        transfer = await upgrades.deployProxy(
            transFactory,
            [
                packet.address,
                clientManager.address,
                accessManager.address
            ]
        ) as Transfer
        await routing.addRouting("FT", transfer.address)
    }
})