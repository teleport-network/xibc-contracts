import { Signer } from "ethers"
import chai from "chai"
import { RCC, Proxy, Routing, ClientManager, MockTendermint, MockTransfer, AccessManager, MockPacket, ERC20, MultiCall } from '../typechain'
import { web3 } from "hardhat"
import { keccak256, sha256 } from "ethers/lib/utils"
const { ethers, upgrades } = require("hardhat")
const { expect } = chai

let client = require("./proto/compiled.js")

describe('Proxy', () => {
    let rcc: RCC
    let accounts: Signer[]
    let mockPacket: MockPacket
    let clientManager: ClientManager
    let routing: Routing
    let tendermint: MockTendermint
    let accessManager: AccessManager
    let mockTransfer: MockTransfer
    let multiCall: MultiCall
    let proxy: Proxy
    let erc20: ERC20
    const srcChainName = "srcChain"
    const destChainName = "destChain"

    before('deploy Proxy', async () => {
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
        await deployProxy()
    })

    it("send", async () => {
        let sender = (await accounts[0].getAddress()).toLocaleLowerCase()
        let reciver = (await accounts[1].getAddress()).toLocaleLowerCase()

        await erc20.approve(proxy.address.toLocaleLowerCase(), 1000)
        let allowance = await erc20.allowance(sender, proxy.address.toLocaleLowerCase())
        expect(allowance.toNumber()).to.eq(1000)

        let ERC20TransferData = {
            tokenAddress: erc20.address.toLocaleLowerCase(),
            receiver: "0x0000000000000000000000000000000010000007",
            amount: 1000,
        }
        let rccTransfer = {
            tokenAddress: "0x9999999999999999999999999999999999999999",
            receiver: reciver,
            amount: 1000,
            destChain: "eth-test",
            relayChain: "",
        }
        await proxy.send(destChainName, ERC20TransferData, ERC20TransferData.receiver, rccTransfer)
        let amount = web3.utils.hexToBytes("0x00000000000000000000000000000000000000000000000000000000000003e8")

        let ERC20TransferPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sender: proxy.address.toLocaleLowerCase(),
            receiver: "0x0000000000000000000000000000000010000007",
            amount: amount,
            token: ERC20TransferData.tokenAddress,
            oriToken: null
        }
        let ERC20TransferPacketDataBz = await client.TokenTransfer.encode(ERC20TransferPacketData).finish()
        let ERC20TransferPacketDataBzHash = Buffer.from(web3.utils.hexToBytes(sha256(ERC20TransferPacketDataBz)))
        let id = sha256(Buffer.from(srcChainName + "/" + destChainName + "/" + 1))
        const agentAbi = web3.eth.abi.encodeFunctionCall(
            {
                name: 'send',
                type: 'function',
                inputs: [
                    {
                        "internalType": "bytes",
                        "name": "id",
                        "type": "bytes"
                    },
                    {
                        "internalType": "address",
                        "name": "tokenAddress",
                        "type": "address"
                    },
                    {
                        "internalType": "string",
                        "name": "receiver",
                        "type": "string"
                    },
                    {
                        "internalType": "uint256",
                        "name": "amount",
                        "type": "uint256"
                    },
                    {
                        "internalType": "string",
                        "name": "destChain",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "relayChain",
                        "type": "string"
                    }
                ],
            }, [id, rccTransfer.tokenAddress, rccTransfer.receiver, rccTransfer.amount.toString(), rccTransfer.destChain, rccTransfer.relayChain]
        )

        let RccPacketData = {
            srcChain: srcChainName,
            destChain: destChainName,
            sender: proxy.address.toLocaleLowerCase(),
            contractAddress: "0x0000000000000000000000000000000010000007",
            data: web3.utils.hexToBytes(agentAbi),
        }
        let RccPacketDataBz = await client.RemoteContractCall.encode(RccPacketData).finish()
        let RccPacketDataBzHash = Buffer.from(web3.utils.hexToBytes(sha256(RccPacketDataBz)))

        let lengthSum = ERC20TransferPacketDataBzHash.length + RccPacketDataBzHash.length
        let sum = Buffer.concat([ERC20TransferPacketDataBzHash, RccPacketDataBzHash], lengthSum)
        let path = "commitments/" + srcChainName + "/" + destChainName + "/sequences/" + 1
        let commitment = await mockPacket.commitments(Buffer.from(path, "utf-8"))
        expect(commitment.toString()).to.eq(sha256(sum))
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

    const deployProxy = async () => {
        const ProxyFactory = await ethers.getContractFactory('Proxy')
        proxy = await upgrades.deployProxy(
            ProxyFactory,
            [
                clientManager.address,
                multiCall.address,
                mockPacket.address,
                mockTransfer.address,
            ]
        ) as Proxy
    }

    const deployAccessManager = async () => {
        const accessFactory = await ethers.getContractFactory('AccessManager')
        accessManager = (await upgrades.deployProxy(accessFactory, [await accounts[0].getAddress()])) as AccessManager
    }

    const deployClientManager = async () => {
        const msrFactory = await ethers.getContractFactory('ClientManager', accounts[0])
        clientManager = (await upgrades.deployProxy(msrFactory, [srcChainName, accessManager.address])) as ClientManager
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

    const deployToken = async () => {
        const tokenFac = await ethers.getContractFactory("testToken")
        erc20 = await tokenFac.deploy("test", "test")
        await erc20.deployed()

        erc20.mint(await accounts[0].getAddress(), 1048576)
        expect((await erc20.balanceOf(await accounts[0].getAddress())).toString()).to.eq("1048576")
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