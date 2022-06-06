import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS
const ENDPOINT_ADDRESS = process.env.ENDPOINT_ADDRESS
const NOT_PROXY = process.env.NOT_PROXY

task("deployEndpoint", "Deploy Transfer")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('Transfer')
        if (NOT_PROXY) {
            const endpoint = await endpointFactory.deploy()
            await endpoint.deployed()

            console.log("Endpoint deployed !")
            console.log("export ENDPOINT_ADDRESS=%s", endpoint.address.toLocaleLowerCase())
        } else {
            const endpoint = await hre.upgrades.deployProxy(
                endpointFactory,
                [
                    String(PACKET_ADDRESS),
                    String(CLIENT_MANAGER_ADDRESS),
                    String(ACCESS_MANAGER_ADDRESS),
                ],
            )
            await endpoint.deployed()
            console.log("Endpoint deployed to:", endpoint.address.toLocaleLowerCase())
            console.log("export ENDPOINT_ADDRESS=%s", endpoint.address.toLocaleLowerCase())
            fs.appendFileSync('env.txt', 'export ENDPOINT_ADDRESS=' + endpoint.address.toLocaleLowerCase() + '\n')
        }

    })

task("upgradeEndpoint", "upgrade transfer")
    .setAction(async (taskArgs, hre) => {
        const MockEndpointFactory = await hre.ethers.getContractFactory("MockEndpoint");
        const mockEndpointProxy = await hre.upgrades.upgradeProxy(
            String(ENDPOINT_ADDRESS),
            MockEndpointFactory,
            {
                unsafeAllowCustomTypes: true,
            }
        );
        await mockEndpointProxy.setVersion(3)
        console.log(mockEndpointProxy.address)
    })

task("setVersion", "set version for mocktransfer")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('MockEndpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_ADDRESS))

        await endpoint.setVersion(2)
    })

task("getVersion", "get version for mocktransfer")
    .setAction(async (taskArgs, hre) => {
        const endpointFactory = await hre.ethers.getContractFactory('MockEndpoint')
        const endpoint = await endpointFactory.attach(String(ENDPOINT_ADDRESS))

        console.log(await endpoint.version())
    })

module.exports = {}
