import { ethers } from "hardhat"
import chai from "chai"

import { TestEd25519 } from '../typechain'
import { utils } from "ethers"


const { expect } = chai

describe('Ed25519', () => {
    let testEd25519: TestEd25519

    before('deploy Ed25519', async () => {
        const sha512Factory = await ethers.getContractFactory('Sha512')
        const sha512 = await sha512Factory.deploy()
        await sha512.deployed()

        const ed25519Factory = await ethers.getContractFactory('Ed25519')
        const ed25519 = await ed25519Factory.deploy()
        await ed25519.deployed()

        const testEd25519Factory = await ethers.getContractFactory(
            'TestEd25519',
            {
                libraries: {
                    Ed25519: ed25519.address,
                },
            })
        testEd25519 = await testEd25519Factory.deploy() as TestEd25519
    })

    for (const { description, pub, msg, sig, valid } of require('./ed25519-tests.json')) {
        it(description, async () => {
            const [r, s] = [sig.substring(0, 64), sig.substring(64)]
            expect(valid).to.eq(await testEd25519.verify(`0x${pub}`, `0x${r}`, `0x${s}`, `0x${msg}`))
        })
    }
})