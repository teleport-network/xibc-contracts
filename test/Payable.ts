import chai from "chai"
import { TestRecl, TestPayable } from '../typechain'
import { web3 } from "hardhat"

const { ethers } = require("hardhat")
const { expect } = chai

describe('Payable', () => {
    let recl: TestRecl
    let payable: TestPayable

    before('deploy Payable', async () => {
        await deployTestRecl()
        await deployPayable()
    })

    it("proxySend", async () => {
        await payable.proxySend(recl.address)
        expect(await web3.eth.getBalance(payable.address)).to.eq("0")
        expect(await web3.eth.getBalance(recl.address)).to.eq("100000")
    })

    it("getether", async () => {
        await recl.getether()
        expect(await web3.eth.getBalance(recl.address)).to.eq("99900")
    })

    it("proxySend", async () => {
        await payable.send(recl.address, { value: 1 })
        await payable.transfer(recl.address, { value: 1 })
        await payable.call(recl.address, { value: 1 })
    })

    const deployTestRecl = async () => {
        const TestReclFactory = await ethers.getContractFactory('TestRecl')
        recl = await TestReclFactory.deploy()
        await recl.saveValue({ value: 100000 })
        expect(await web3.eth.getBalance(recl.address)).to.eq("100000")
    }

    const deployPayable = async () => {
        const PayableFactory = await ethers.getContractFactory('TestPayable')
        payable = await PayableFactory.deploy()
    }
})