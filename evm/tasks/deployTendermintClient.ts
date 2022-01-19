import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const CLIENT_STATE_CODEC_ADDRESS = process.env.CLIENT_STATE_CODEC_ADDRESS
const CONSENSUS_STATE_CODEC_ADDRESS = process.env.CONSENSUS_STATE_CODEC_ADDRESS
const VERIFIER_ADDRESS = process.env.VERIFIER_ADDRESS
const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS

task("deployTendermint", "Deploy Tendermint Client")
    .setAction(async (taskArgs, hre) => {
        const HeaderCodec = await hre.ethers.getContractFactory('HeaderCodec')
        const headerCodec = await HeaderCodec.deploy()
        await headerCodec.deployed()
        const tendermintFactory = await hre.ethers.getContractFactory(
            'Tendermint',
            {
                libraries: {
                    ClientStateCodec: String(CLIENT_STATE_CODEC_ADDRESS),
                    ConsensusStateCodec: String(CONSENSUS_STATE_CODEC_ADDRESS),
                    Verifier: String(VERIFIER_ADDRESS),
                    HeaderCodec: String(headerCodec.address),

                }
            },
        )

        const tendermint = await hre.upgrades.deployProxy(
            tendermintFactory,
            [String(CLIENT_MANAGER_ADDRESS)],
            { "unsafeAllowLinkedLibraries": true }
        )
        await tendermint.deployed()
        console.log("Tendermint deployed to:", tendermint.address)
    })

module.exports = {}
