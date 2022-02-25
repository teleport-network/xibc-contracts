import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const ACCESS_MANAGER_ADDRESS = process.env.ACCESS_MANAGER_ADDRESS
const TRANSFER_ADDRESS = process.env.TRANSFER_ADDRESS

task("deployTransfer", "Deploy Transfer")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await hre.upgrades.deployProxy(
            transferFactory,
            [
                String(PACKET_ADDRESS),
                String(CLIENT_MANAGER_ADDRESS),
                String(ACCESS_MANAGER_ADDRESS),
            ],
        )
        await transfer.deployed()
        console.log("Transfer deployed to:", transfer.address.toLocaleLowerCase())
        console.log("export TRANSFER_ADDRESS=%s", transfer.address.toLocaleLowerCase())
    })

task("upgradeTransfer", "upgradeProxy")
    .setAction(async (taskArgs, hre) => {
        const MockTransferFactory = await hre.ethers.getContractFactory("MockTransfer");
        const mockTransferProxy = await hre.upgrades.upgradeProxy(
            String(TRANSFER_ADDRESS),
            MockTransferFactory,
            {
                unsafeAllowCustomTypes: true,
            }
        );
        await mockTransferProxy.setVersion(3)
        console.log(mockTransferProxy.address)
    })

task("setVersion", "upgradeProxy")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('MockTransfer')
        const transfer = await transferFactory.attach(String(TRANSFER_ADDRESS))

        await transfer.setVersion(2)
    })

task("getVersion", "upgradeProxy")
    .setAction(async (taskArgs, hre) => {
        const transferFactory = await hre.ethers.getContractFactory('MockTransfer')
        const transfer = await transferFactory.attach(String(TRANSFER_ADDRESS))

        console.log(await transfer.version())
    })

module.exports = {}
