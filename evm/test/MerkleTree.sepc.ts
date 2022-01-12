import { ethers } from "hardhat"
import { Signer } from "ethers"
import chai from "chai"
import { TestMerkleTree, TestLightClient } from '../typechain'

const { expect } = chai

let client = require("./proto/compiled.js")

describe('TestMerkleTree', () => {
    let accounts: Signer[]
    let testMerkleTree: TestMerkleTree
    let light: TestLightClient

    before('deploy TestMerkleTree', async () => {
        accounts = await ethers.getSigners()
        const mkFactory = await ethers.getContractFactory('TestMerkleTree', accounts[0])
        testMerkleTree = await mkFactory.deploy() as TestMerkleTree

        const HeaderCodec = await ethers.getContractFactory('HeaderCodec')
        const headerCodec = await HeaderCodec.deploy()
        await headerCodec.deployed()

        const lcFactory = await ethers.getContractFactory('TestLightClient',
            {
                libraries: {
                    HeaderCodec: headerCodec.address,
                },
            })
        light = await lcFactory.deploy() as TestLightClient
    })

    it("test hashFromByteSlices", async () => {
        let data: any = [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]]
        let root = await testMerkleTree.hashFromByteSlices(data)
        expect(root).to.eq("0xf326493eceab4f2d9ffbc78c59432a0a005d6ea98392045c74df5d14a113be18")
    })

    it("test verifyMembership", async () => {
        let proofBz = Buffer.from("0a1f0a1d0a054d594b455912074d5956414c55451a0b0801180120012a030002020a3d0a3b0a0c6961766c53746f72654b65791220a758f4decb5c7b9d4a45601b60400c638c9c3eef5380fbc29f0c638613be75c71a090801180120012a0100", "hex")
        let specsBz: any = [
            Buffer.from("0a090801180120012a0100120c0a02000110211804200c3001", "hex"),
            Buffer.from("0a090801180120012a0100120c0a0200011020180120013001", "hex"),
        ]
        let rootBz = Buffer.from("0a20edc765d6a5287a238227cf19f101b201922cbaec0f915b2c7bc767aa6368c3b5", "hex")
        let pathBz = Buffer.from("0a0c6961766c53746f72654b65790a054d594b4559", "hex")
        let value = Buffer.from("4d5956414c5545", "hex")
        await testMerkleTree.verifyMembership(proofBz, specsBz, rootBz, pathBz, value)
    })

    it("test genValidatorSetHash", async () => {
        let data: any = Buffer.from("0a3c0a14c42d7c8a0a7a831c19fbda4b050910629bf2b16b12220a208522460be5acf8faefedca5b72b8a546f9ce485f2155815a529ed132b0fdcc721864123c0a14c42d7c8a0a7a831c19fbda4b050910629bf2b16b12220a208522460be5acf8faefedca5b72b8a546f9ce485f2155815a529ed132b0fdcc721864", "hex")
        let valSetHash = await light.genValidatorSetHash(data)
        expect(valSetHash).to.eq("0x0757f0bc673f8df26d61d3e74bb6181ac9df88c09a1100c6fade264604b4c478")
    })

    it("test genHeaderHash", async () => {
        let headerBz = Buffer.from("0ad6040a9b030a02080b12156269746f735f383436303837343734383537302d311864220c08affea58e0610d8b1c5a6032a480a20448029cef2a0c3162834da3804e3cd1a176b244b9c1a121768ec82647bb3ca861224080112200ea3311ffc959657ff574f8b4d22afe4a00cefff2beebd8a9b7172760f046d9e32209d524281a526c38f7115a352fd4938873e2a509e8477a6ca68f1deedbc2a13d73a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855422076dc06e3ac060bd158193b71bb7fb206efbbdef70fc6f507cca866982cb1d5a14a2076dc06e3ac060bd158193b71bb7fb206efbbdef70fc6f507cca866982cb1d5a15220048091bc7ddc283f77bfbf91d73c44da58c3df8a9cbc867405d8b7f3daada22f5a20f38642d8af194b7ab086c584eee93961191094d9e5c77ed6b0f9c58c035bb9476220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8556a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8557214001938ce7a5a92374c24db936762929b9e25fe6412b50108641a480a2031ab915ba6a8f6aac473d7d04723864086cdcea080855d5965137ffccae2c6bc12240801122013d5f9f34c99587f4cd4ddb1757a541a7a70c2f6927364588d4c65d27fbc20fe226708021214001938ce7a5a92374c24db936762929b9e25fe641a0b08b5fea58e0610e89dfb1a22400de9321f8371f23fa388043898671d5fab3725062c1d6611b719ddc462901b65f34ee1ef60ae82ed30ba5bb1b8dc21254ce0af6802ecc8ae9707c20d7da411021290010a420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de1612420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de16188080e983b1de161a0210632290010a420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de1612420a14001938ce7a5a92374c24db936762929b9e25fe6412220a20e686a45cfa89bdc7295f3b624381d6f28c14d6995fb5103774a458b33ba34056188080e983b1de16188080e983b1de16", "hex")
        let header = client.Header.decode(headerBz)
        let result = await light.genHeaderHash(headerBz)
        expect(result).to.eq("0x31ab915ba6a8f6aac473d7d04723864086cdcea080855d5965137ffccae2c6bc")
    })
})