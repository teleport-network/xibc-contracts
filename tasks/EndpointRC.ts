import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

const PACKET_RC_ADDRESS = process.env.PACKET_RC_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS
const NOT_PROXY = process.env.NOT_PROXY

task("deployEndpointRC", "Deploy Endpoint")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('EndpointRC')
        if (NOT_PROXY) {
            const endpoint = await endpointFactory.deploy()
            await endpoint.deployed()

            console.log("Endpoint deployed !")
            console.log("export ENDPOINT_RC_ADDRESS=%s", endpoint.address.toLocaleLowerCase())
        } else {
            const endpoint = await hre.upgrades.deployProxy(
                endpointFactory,
                [
                    String(PACKET_RC_ADDRESS),
                    String(ACCESS_MANAGER_ADDRESS),
                ],
            )
            await endpoint.deployed()
            console.log("Endpoint deployed to:", endpoint.address.toLocaleLowerCase())
            console.log("export ENDPOINT_RC_ADDRESS=%s", endpoint.address.toLocaleLowerCase())
            fs.appendFileSync('env.txt', 'export ENDPOINT_RC_ADDRESS=' + endpoint.address.toLocaleLowerCase() + '\n')
        }

    })

module.exports = {}
