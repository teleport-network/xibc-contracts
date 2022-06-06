import { ethers, upgrades } from "hardhat"
import { Signer } from "ethers"
import { ClientManager, Tendermint, AccessManager } from '../typechain'
import chai from "chai"
import keccak256 from 'keccak256'

const { expect } = chai

let client = require("./proto/compiled.js")

describe('Tendermint', () => {
    let accounts: Signer[]
    let tendermint: Tendermint
    let clientManager: ClientManager
    let accessManager: AccessManager

    before('deploy Tendermint', async () => {
        accounts = await ethers.getSigners()
        await deployAccessManager()
        await deployClientManager()
        await deployTendermint()
        await initialize()
    })

    it("test updateClient ", async () => {
        // updateClientAdjacent update to 13957
        let root = Buffer.from("D8FCCC59F08E68A91E70F9828964DD79E10EBD0D063F96C13EAB899CC855EE11", "hex")
        let next_validators_hash = Buffer.from("76DC06E3AC060BD158193B71BB7FB206EFBBDEF70FC6F507CCA866982CB1D5A1", "hex")
        let headerBz = Buffer.from("0ad8040a9b030a02080b12156269746f735f383436303837343734383537302d31189d6a220b08abc7b48e0610e8a893732a480a20aa247a6730feacffe1be8d230154190c86b0cc40a13f431cae9db7a50a191c9c12240801122001d000a7c5d127cf37e574041d6363ad6073d192a39aa3c1ba13178cb8b71d7c322045a0fbe664022b430f2291f526ae81a11b9f9ac535c692e02ad13a803d0fb6453a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855422076dc06e3ac060bd158193b71bb7fb206efbbdef70fc6f507cca866982cb1d5a14a2076dc06e3ac060bd158193b71bb7fb206efbbdef70fc6f507cca866982cb1d5a15220048091bc7ddc283f77bfbf91d73c44da58c3df8a9cbc867405d8b7f3daada22f5a20d8fccc59f08e68a91e70f9828964dd79e10ebd0d063f96c13eab899cc855ee116220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8556a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8557214001938ce7a5a92374c24db936762929b9e25fe6412b701089d6a1a480a20774aecee679df3fde4f4cc9d61d3ba3517c33ef0b6561c52efe072851b3f46fb122408011220571f6a1fcacc1f70c6c8004c5695b16e24707593fc7284062dd9c1ec5c456d8c226808021214001938ce7a5a92374c24db936762929b9e25fe641a0c08b0c7b48e0610a0ebe8c101224000a58b3fbf576459d0a55312a3fd066e79f93dfefee3f61d3e16a72e851ff48938a9b2ef769508d08ae5a54a96200d08aaaa8be5a5de32a920a5948b9aecb8011290010a420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de1612420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de16188080e983b1de161a03109c6a2290010a420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de1612420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de16188080e983b1de16", "hex")
        let result = await clientManager.updateClient(headerBz)
        await result.wait()

        let clientState = await tendermint.clientState()
        let expConsensusState = await tendermint.getConsensusState(clientState.latest_height)
        expect(expConsensusState.root.slice(2)).to.eq(root.toString("hex"))
        expect(expConsensusState.next_validators_hash.slice(2)).to.eq(next_validators_hash.toString("hex"))

        // updateClientNonAdjacent update to 14000
        root = Buffer.from("554AB651C2D633274A261914F6607C88F41235BD16DF6792E6DE84E801C1F687", "hex")
        next_validators_hash = Buffer.from("76DC06E3AC060BD158193B71BB7FB206EFBBDEF70FC6F507CCA866982CB1D5A1", "hex")
        headerBz = Buffer.from("0ad9040a9c030a02080b12156269746f735f383436303837343734383537302d3118b06d220c08cbd7b48e0610f0c7c4a9012a480a20fa6c2299d4577179dbb21f84c3d3e17c489ded6ef15a1b2f6ba9d21e9872eb9212240801122002bc7b9cb682e52b4291cc62f55e5584ca5f688b55bcdb213fe113bfdcfefea43220efeeec4d4cd9217bbcf1095bc5c3336d4f7a8a822f685819ae22385f1f203e223a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855422076dc06e3ac060bd158193b71bb7fb206efbbdef70fc6f507cca866982cb1d5a14a2076dc06e3ac060bd158193b71bb7fb206efbbdef70fc6f507cca866982cb1d5a15220048091bc7ddc283f77bfbf91d73c44da58c3df8a9cbc867405d8b7f3daada22f5a20554ab651c2d633274a261914f6607c88f41235bd16df6792e6de84e801c1f6876220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8556a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8557214001938ce7a5a92374c24db936762929b9e25fe6412b70108b06d1a480a2067624e9652bac0c5ec9296dae874642000612a8a9d00677a195eead6ee2ec8b31224080112206220eef33f634b0ce77d281579f05fe1c05180cc3df474076cad392bb87492c1226808021214001938ce7a5a92374c24db936762929b9e25fe641a0c08d0d7b48e0610e8d2c3850222402b95e30039277965b56d7d9e92bb3afaa1fac938db43ad7270f03fe4c9cf9717fcefccef5c45fb2f7914e46ac14ee6026470850fd74d2c4cfb07e05707ecd2031290010a420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de1612420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de16188080e983b1de161a03109d6a2290010a420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de1612420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de16188080e983b1de16", "hex")
        result = await clientManager.updateClient(headerBz)
        await result.wait()

        clientState = await tendermint.clientState()
        expConsensusState = await tendermint.getConsensusState(clientState.latest_height)
        expect(expConsensusState.root.slice(2)).to.eq(root.toString("hex"))
        expect(expConsensusState.next_validators_hash.slice(2)).to.eq(next_validators_hash.toString("hex"))
    })

    it("upgrade clientManager", async () => {
        const mockClientManagerFactory = await ethers.getContractFactory("MockClientManager")
        const upgradedClientManager = await upgrades.upgradeProxy(clientManager.address, mockClientManagerFactory)
        expect(upgradedClientManager.address).to.eq(clientManager.address)

        const result = await upgradedClientManager.getLatestHeight()
        expect(14000).to.eq(result[1].toNumber())

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

    const deployTendermint = async () => {
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

    const createClient = async function (lightClientAddress: any, clientState: any, consensusState: any) {
        let clientStateBuf = client.ClientState.encode(clientState).finish()
        let consensusStateBuf = client.ConsensusState.encode(consensusState).finish()
        await clientManager.createClient(lightClientAddress, clientStateBuf, consensusStateBuf)
    }

    const initialize = async () => {
        // create light client
        let clientState = {
            chainId: "ethereum",
            trustLevel: { numerator: 1, denominator: 3 },
            trustingPeriod: 1000 * 24 * 60 * 60,
            unbondingPeriod: 1814400,
            maxClockDrift: 10,
            latestHeight: { revisionNumber: 0, revisionHeight: 13596 },
            merklePrefix: { keyPrefix: Buffer.from("xibc") },
            timeDelay: 10,
        }

        let consensusState = {
            timestamp: { secs: 1631155726, nanos: 5829 },
            root: Buffer.from("A1D01EF12B6D2D5375681CF2BBD24302E4E7F03B7FF53144090224D3BB516458", "hex"),
            nextValidatorsHash: Buffer.from("76DC06E3AC060BD158193B71BB7FB206EFBBDEF70FC6F507CCA866982CB1D5A1", "hex")
        }

        await createClient(tendermint.address, clientState, consensusState)

        let teleportClient = await clientManager.client()
        expect(teleportClient).to.eq(tendermint.address)

        let latestHeight = await clientManager.getLatestHeight()
        expect(latestHeight[0].toNumber()).to.eq(clientState.latestHeight.revisionNumber)
        expect(latestHeight[1].toNumber()).to.eq(clientState.latestHeight.revisionHeight)

        let expClientState = (await tendermint.clientState())
        expect(expClientState.chain_id).to.eq(clientState.chainId)

        let key: any = {
            revision_number: clientState.latestHeight.revisionNumber,
            revision_height: clientState.latestHeight.revisionHeight,
        }

        let expConsensusState = (await tendermint.getConsensusState(key))
        expect(expConsensusState.root.slice(2)).to.eq(consensusState.root.toString("hex"))
        expect(expConsensusState.next_validators_hash.slice(2)).to.eq(consensusState.nextValidatorsHash.toString("hex"))

        let relayerRole = keccak256("RELAYER_ROLE")
        let signer = await accounts[0].getAddress()
        let ret = await accessManager.grantRole(relayerRole, signer)
        expect(ret.blockNumber).to.greaterThan(0)
    }
})