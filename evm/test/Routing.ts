import { ethers, upgrades } from "hardhat"
import { Signer } from "ethers"
import chai from "chai"

import { Routing, AccessManager } from '../typechain'

const { expect } = chai

describe('Routing', () => {
    let accounts: Signer[]
    let routing: Routing

    before('deploy Routing', async () => {
        accounts = await ethers.getSigners()

        const accessFactory = await ethers.getContractFactory('AccessManager')
        const accessManager = await upgrades.deployProxy(accessFactory, [await accounts[0].getAddress()]) as AccessManager

        const msrFactory = await ethers.getContractFactory('Routing')
        routing = await upgrades.deployProxy(msrFactory, [accessManager.address]) as Routing
    })

    it("upgrade routing", async () => {
        const mockRoutingUpgradeFactory = await ethers.getContractFactory("MockRoutingUpgrade")
        const upgradedRouting = await upgrades.upgradeProxy(routing.address, mockRoutingUpgradeFactory)
        expect(upgradedRouting.address).to.eq(routing.address)

        await upgradedRouting.setVersion(2)
        const version = await upgradedRouting.version()
        expect(2).to.eq(version.toNumber())
    })
})