import { Signer } from "ethers"
import chai from "chai"
import { ERC20MinterBurnerDecimals, TestTransfer } from '../typechain'

const { expect } = chai
const { ethers } = require("hardhat")
const keccak256 = require('keccak256')

describe('Transfer', () => {
    let accounts: Signer[]
    let erc20: ERC20MinterBurnerDecimals
    let transfer: TestTransfer

    before('deploy Token', async () => {
        accounts = await ethers.getSigners()
        await deployTestTransfer()
        await deployToken()
    })

    it("test check role and mint", async () => {
        expect(await erc20.hasRole(keccak256("MINTER_ROLE"), transfer.address)).to.eq(true)
        await erc20.mint(await accounts[1].getAddress(), 1000)
        expect(await erc20.balanceOf(await accounts[1].getAddress())).to.eq("1000")
    })

    it("test transfer.mint approve and transfer.burn", async () => {
        let account = (await accounts[0].getAddress()).toString()
        await transfer.mint(erc20.address, account, 1000)
        await erc20.approve(transfer.address, 1000)
        await transfer.burn(erc20.address, account, 100)
        expect(await erc20.balanceOf(account)).to.eq("900")
    })

    const deployToken = async () => {
        const ERC20Factory = await ethers.getContractFactory('ERC20MinterBurnerDecimals')
        erc20 = await ERC20Factory.deploy("Tele", "atele", 18, transfer.address)
    }

    const deployTestTransfer = async () => {
        const testTransferFactory = await ethers.getContractFactory('TestTransfer')
        transfer = await testTransferFactory.deploy()
    }

})