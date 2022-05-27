import { ethers, upgrades } from "hardhat"
import { Signer, utils } from "ethers"
import chai from "chai"
import { ClientManager, TssClient, AccessManager } from '../typechain'

const keccak256 = require('keccak256')
const { expect } = chai

describe('TSS', () => {
    let accounts: Signer[]
    let tssClient: TssClient
    let clientManager: ClientManager
    let accessManager: AccessManager

    before('deploy Tss', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTssClient()
        await initialize()
    })

    it("test updateClient", async () => {
        let privateKey = "0x9876543210012345678901234567890123456789012345678901234567890123";
        let pubkey = "0xda9e4d43b0d24e079ca8255ff22515db1e62416e3ec6be512b1843a022bde4c7982b3a9129ee55482cff8d0d871c2489c1a1a176c0a62bdefd7fdf9a5a65286d"
        let wallet = new ethers.Wallet(privateKey);

        let headerBz = utils.defaultAbiCoder.encode(
            ["tuple(bytes,bytes[])"],
            [[pubkey, [pubkey]]]
        )

        let result = await clientManager.updateClient(headerBz)
        await result.wait()

        let clientState = await tssClient.getClientState()
        expect(clientState.tss_address).to.eq(wallet.address)
        expect(clientState.pubkey).to.eq(pubkey)
        expect(clientState.part_pubkeys[0]).to.eq(pubkey)
    })

    it("upgrade clientManager", async () => {
        const mockClientManagerFactory = await ethers.getContractFactory("MockClientManager")
        const upgradedClientManager = await upgrades.upgradeProxy(clientManager.address, mockClientManagerFactory)
        expect(upgradedClientManager.address).to.eq(clientManager.address)

        const result = await upgradedClientManager.getLatestHeight()
        expect(0).to.eq(result[0].toNumber())

        await upgradedClientManager.setVersion(2)
        const version = await upgradedClientManager.version()
        expect(2).to.eq(version.toNumber())
    })

    const deployAccessManager = async () => {
        const accessFactory = await ethers.getContractFactory('AccessManager')
        accessManager = (await upgrades.deployProxy(accessFactory, [await accounts[0].getAddress()])) as AccessManager
    }

    const deployClientManager = async () => {
        const msrFactory = await ethers.getContractFactory('ClientManager', accounts[0])
        clientManager = (await upgrades.deployProxy(msrFactory, [accessManager.address])) as ClientManager
    }

    const deployTssClient = async () => {
        const tssFactory = await ethers.getContractFactory('TssClient')
        tssClient = await upgrades.deployProxy(tssFactory, [clientManager.address]) as TssClient
    }

    const initialize = async () => {
        let privateKey = "0x0123456789012345678901234567890123456789012345678901234567890123";
        let pubkey = "0x6655feed4d214c261e0a6b554395596f1f1476a77d999560e5a8df9b8a1a3515217e88dd05e938efdd71b2cce322bf01da96cd42087b236e8f5043157a9c068e"
        let wallet = new ethers.Wallet(privateKey);
        let signer = await accounts[0].getAddress();

        // create light client
        let clientStateBz = utils.defaultAbiCoder.encode(
            ["tuple(address,bytes,bytes[])"],
            [[wallet.address, pubkey, [pubkey]]],
        )

        await clientManager.createClient(tssClient.address, clientStateBz, Buffer.from(""))

        let teleportClient = await clientManager.client()
        expect(teleportClient).to.eq(tssClient.address)

        let expClientState = (await tssClient.getClientState())
        expect(expClientState.pubkey).to.eq(pubkey)
        expect(expClientState.tss_address).to.eq(wallet.address)
        expect(expClientState.part_pubkeys[0]).to.eq(pubkey)

        let relayerRole = keccak256("RELAYER_ROLE")
        let ret = await accessManager.grantRole(relayerRole, signer)
        expect(ret.blockNumber).to.greaterThan(0)
    }
})