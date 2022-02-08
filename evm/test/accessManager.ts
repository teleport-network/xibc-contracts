import { ethers, upgrades } from "hardhat"
import { Signer } from "ethers"
import chai from "chai"

import { AccessManager } from '../typechain'

const { expect } = chai
const keccak256 = require('keccak256')

describe('AccessManager', () => {
    let accounts: Signer[]
    let accessManager: AccessManager

    let test1Role = keccak256("TEST_1_ROLE")

    before('deploy AccessManager', async () => {
        accounts = await ethers.getSigners()
        let multiAddr = await accounts[0].getAddress()

        const accessFactory = await ethers.getContractFactory('AccessManager')
        accessManager = await upgrades.deployProxy(accessFactory, [multiAddr]) as AccessManager
    })

    it("add role should true", async () => {
        let operator = (await accounts[0].getAddress()).toString()
        await accessManager.grantRole(test1Role, operator)

        let result = await accessManager.hasRole(test1Role, operator)
        expect(result).to.equal(true)
    })

    it("grant role & revoke role should true", async () => {
        let operator = (await accounts[0].getAddress()).toString()
        let authorizedPerson = (await accounts[1].getAddress()).toString()
        await accessManager.grantRole(test1Role, operator)

        // grant role
        await accessManager.grantRole(test1Role, authorizedPerson)
        let grantResult = await accessManager.hasRole(test1Role, authorizedPerson)
        expect(grantResult).to.equal(true)

        // revoke role
        await accessManager.revokeRole(test1Role, authorizedPerson)
        let revokeResult = await accessManager.hasRole(test1Role, authorizedPerson)
        expect(revokeResult).to.equal(false)

    })

    it("batch add role should true", async () => {
        let addr0 = (await accounts[0].getAddress()).toString()
        let addr1 = (await accounts[1].getAddress()).toString()

        let test1Role = keccak256("TEST_1_ROLE")
        let test2Role = keccak256("TEST_2_ROLE")

        var roles = [test1Role, test2Role]
        var addrs = [addr0, addr1]

        await accessManager.batchGrantRole(roles, addrs)

        let result = await accessManager.hasRole(test1Role, addr0)
        expect(result).to.equal(true)

        let result1 = await accessManager.hasRole(test2Role, addr1)
        expect(result1).to.equal(true)
    })

    it("batch grant role & revoke role should true", async () => {
        // batch add role 
        let addr0 = (await accounts[0].getAddress()).toString()
        let addr1 = (await accounts[1].getAddress()).toString()
        let addr2 = (await accounts[2].getAddress()).toString()
        let addr3 = (await accounts[3].getAddress()).toString()

        let test1Role = keccak256("TEST_1_ROLE")
        let test2Role = keccak256("TEST_2_ROLE")

        var roles = [test1Role, test2Role]
        var addrsAdd = [addr0, addr1]

        await accessManager.batchGrantRole(roles, addrsAdd)

        let result = await accessManager.hasRole(test1Role, addr0)
        expect(result).to.equal(true)

        let result1 = await accessManager.hasRole(test2Role, addr1)
        expect(result1).to.equal(true)

        // batch grant role
        var addrsGrant = [addr2, addr3]
        await accessManager.batchGrantRole(roles, addrsGrant)

        let result2 = await accessManager.hasRole(test1Role, addr2)
        expect(result2).to.equal(true)

        let result3 = await accessManager.hasRole(test2Role, addr3)
        expect(result3).to.equal(true)

        // batch revoke role 
        await accessManager.batchRevokeRole(roles, addrsGrant)

        let result4 = await accessManager.hasRole(test1Role, addr2)
        expect(result4).to.equal(false)

        let result5 = await accessManager.hasRole(test2Role, addr3)
        expect(result5).to.equal(false)
    })
})