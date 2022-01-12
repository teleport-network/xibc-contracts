import { Signer, BigNumber } from "ethers"
import chai from "chai"
import { Transfer, MockPacket, ClientManager, Routing, Tendermint, AccessManager, ERC20 } from '../typechain'
import { randomBytes } from "crypto"

const { expect } = chai
const { ethers, upgrades } = require("hardhat")
const keccak256 = require('keccak256')

let client = require("./proto/compiled.js")

describe('Transfer', () => {
    let accounts: Signer[]
    let transfer: Transfer
    let mockPacket: MockPacket
    let clientManager: ClientManager
    let routing: Routing
    let tendermint: Tendermint
    let accessManager: AccessManager
    let erc20: ERC20
    let chainName = "teleport"
    const srcChainName = "ethereumsrc"
    const destChainName = "ethereumdest"
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
        await initialize()
    })

    it("test transfer ERC20", async () => {
        let balances = (await erc20.balanceOf(await accounts[0].getAddress())).toString()
        expect(balances.toString()).to.eq("10000000000000")

        let transferData = {
            tokenAddress: erc20.address,
            receiver: (await accounts[1].getAddress()),
            amount: 1024,
            destChain: destChainName,
            relayChain: "",
        }

        transfer.sendTransferERC20(transferData)
        let outToken = (await transfer.outTokens(erc20.address, destChainName))
        balances = (await erc20.balanceOf(await accounts[0].getAddress())).toString()
        expect(outToken).to.eq(1024)
        expect(balances.toString()).to.eq("9999999998976")
    })

    it("test transfer Base", async () => {
        let transferData = {
            receiver: (await accounts[1].getAddress()),
            destChain: destChainName,
            relayChain: "",
        }
        transfer.sendTransferBase(
            transferData,
            { value: 10000 }
        )

        let outToken = (await transfer.outTokens("0x0000000000000000000000000000000000000000", destChainName))
        expect(outToken.toString()).to.eq("10000")
    })

    it("test receive packet", async () => {
        let account = await accounts[2].getAddress()
        let proof = Buffer.from("proof", "utf-8")
        let height = {
            revision_number: 1,
            revision_height: 1,
        }
        let amount = new Int32Array([0, 0, 0, 1])
        let transferData = {
            srcChain: destChainName,
            destChain: srcChainName,
            receiver: account,
            amount: amount,
            token: "0x0000000000000000000000000000000000000000",
        }

        let transferByte = client.TokenTransfer.encode(transferData).finish()
        let sequence: BigNumber = BigNumber.from(1)
        let pac = {
            sequence: sequence,
            sourceChain: destChainName,
            destChain: srcChainName,
            relayChain: relayChainName,
            ports: ["FT"],
            dataList: [transferByte],
        }
        await transfer.bindToken(erc20.address, transferData.token, transferData.srcChain)

        let trace = await transfer.bindingTraces(transferData.srcChain + "/" + transferData.token)
        expect(trace.toString()).to.eq(erc20.address)

        await mockPacket.recvPacket(pac, proof, height)
        let binds = await transfer.bindings(erc20.address)
        let balances = (await erc20.balanceOf(account)).toString()
        let totalSupply = (await erc20.totalSupply()).toString()

        expect(binds.amount.toString()).to.eq("1")
        expect(totalSupply).to.eq("10000000000001")
        expect(balances).to.eq("1")
    })

    it("upgrade transfer", async () => {
        // upgrade transfer contract and check the contract address    
        const mockTransferFactory = await ethers.getContractFactory("MockTransferUpgrade");
        const upgradedTransfer = await upgrades.upgradeProxy(transfer.address, mockTransferFactory);
        expect(upgradedTransfer.address).to.eq(transfer.address);

        // Verify that old data can be accessed
        let trace = await upgradedTransfer.bindingTraces(destChainName + "/" + "0x0000000000000000000000000000000000000000")
        expect(trace.toString()).to.eq(erc20.address)
        let binds = await upgradedTransfer.bindings(trace)
        expect(binds.amount.toString()).to.eq("1")
        let outToken = (await upgradedTransfer.outTokens("0x0000000000000000000000000000000000000000", destChainName))
        expect(outToken.toString()).to.eq("10000")

        // Verify new func in upgradeTransfer 
        await upgradedTransfer.setVersion(1)
        const version = await upgradedTransfer.version();
        expect(1).to.eq(version.toNumber())

        // The old method of verifying that has been changed
        let account = await accounts[3].getAddress()
        let amount = new Int32Array([0, 0, 0, 1])
        let transferData = {
            srcChain: destChainName,
            destChain: srcChainName,
            receiver: account,
            amount: amount,
            token: "0x0000000000000000000000000000000000000000",
        }

        let transferByte = client.TokenTransfer.encode(transferData).finish()
        await upgradedTransfer.onRecvPacket(transferByte)
        let balances = (await erc20.balanceOf(account)).toString()
        expect(balances).to.eq("1")
    })

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
        const mockPacketFactory = await ethers.getContractFactory("MockPacket")
        mockPacket = await mockPacketFactory.deploy() as MockPacket
    }

    const deployTransfer = async () => {
        const transFactory = await ethers.getContractFactory("Transfer")
        transfer = await upgrades.deployProxy(
            transFactory,
            [
                mockPacket.address,
                clientManager.address,
                accessManager.address
            ]
        ) as Transfer
        await routing.addRouting("FT", transfer.address)
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

        mockPacket.setModule(transfer.address)
    }
})