import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

task("deployall", "Deploy all base contract")
    .addParam("chain", "Chain Name")
    .addParam("wallet", "multi sign address")
    .setAction(async (taskArgs, hre) => {
        console.log("deploy contracts:")
        const ClientStateCodec = await hre.ethers.getContractFactory('ClientStateCodec')
        const clientStateCodec = await ClientStateCodec.deploy()
        await clientStateCodec.deployed()

        const ConsensusStateCodec = await hre.ethers.getContractFactory('ConsensusStateCodec')
        const consensusStateCodec = await ConsensusStateCodec.deploy()
        await consensusStateCodec.deployed()

        const ProofCodec = await hre.ethers.getContractFactory('ProofCodec')
        const proofCodec = await ProofCodec.deploy()
        await proofCodec.deployed()

        const LightClientVerify = await hre.ethers.getContractFactory('LightClientVerify')
        const lightClientVerify = await LightClientVerify.deploy()
        await lightClientVerify.deployed()

        const LightClientGenValHash = await hre.ethers.getContractFactory('LightClientGenValHash')
        const lightClientGenValHash = await LightClientGenValHash.deploy()
        await lightClientGenValHash.deployed()

        const Verifier = await hre.ethers.getContractFactory(
            'Verifier',
            { libraries: { ProofCodec: proofCodec.address, } }
        )
        const verifierLib = await Verifier.deploy()
        await verifierLib.deployed()
        console.log("export CLIENT_STATE_CODEC_ADDRESS=%s", clientStateCodec.address.toLocaleLowerCase())
        console.log("export CONSENSUS_STATE_CODEC_ADDRESS=%s", consensusStateCodec.address.toLocaleLowerCase())
        console.log("export PROOF_CODEC_ADDRESS=%s", proofCodec.address.toLocaleLowerCase())
        console.log("export VERIFIER_ADDRESS=%s", verifierLib.address.toLocaleLowerCase())
        console.log("export LIGHT_CLIENT_VERIFY_ADDRESS=%s", lightClientVerify.address.toLocaleLowerCase())
        console.log("export LIGHT_CLIENT_GEN_VALHASH_ADDRESS=%s", lightClientGenValHash.address.toLocaleLowerCase())
        console.log("")

        const accessManagerFactory = await hre.ethers.getContractFactory('AccessManager')
        const accessManager = await hre.upgrades.deployProxy(
            accessManagerFactory,
            [taskArgs.wallet]
        )
        await accessManager.deployed()
        console.log("export ACCESS_MANAGER_ADDRESS=%s", accessManager.address.toLocaleLowerCase())

        const clientManagerFactory = await hre.ethers.getContractFactory('ClientManager')
        const clientManager = await hre.upgrades.deployProxy(
            clientManagerFactory,
            [
                accessManager.address.toLocaleLowerCase(),
            ]
        )
        await clientManager.deployed()
        console.log("export CLIENT_MANAGER_ADDRESS=%s", clientManager.address.toLocaleLowerCase())

        const packetFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/packet/Packet.sol:Packet')
        const packet = await hre.upgrades.deployProxy(
            packetFactory,
            [
                taskArgs.chain,
                'teleport',
                clientManager.address.toLocaleLowerCase(),
                accessManager.address.toLocaleLowerCase()
            ]
        )
        await packet.deployed()
        console.log("export PACKET_ADDRESS=%s", packet.address.toLocaleLowerCase())

        const endpointFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/endpoint/Endpoint.sol:Endpoint')
        const endpoint = await hre.upgrades.deployProxy(
            endpointFactory,
            [
                packet.address.toLocaleLowerCase(),
                clientManager.address.toLocaleLowerCase(),
                accessManager.address.toLocaleLowerCase()
            ],
        )
        await endpoint.deployed()
        console.log("export ENDPOINT_ADDRESS=%s", endpoint.address.toLocaleLowerCase())

        const executeFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/endpoint/Execute.sol:Execute')
        const execute = await hre.upgrades.deployProxy(
            executeFactory,
            [
                packet.address.toLocaleLowerCase(),
            ],
        )
        await execute.deployed()
        console.log("export EXECUTE_ADDRESS=%s", execute.address.toLocaleLowerCase())

        console.log(await packet.initEndpoint(endpoint.address.toLocaleLowerCase(),execute.address.toLocaleLowerCase()))
    })

task("transferOwnership", "Deploy all base contract")
    .addParam("gnosissafe", "gnosisSafe address")
    .setAction(async (taskArgs, hre) => {
        console.log('Transferring ownership of ProxyAdmin...');
        // The owner of the ProxyAdmin can upgrade our contracts
        await hre.upgrades.admin.transferProxyAdminOwnership(taskArgs.gnosissafe);
        console.log('Transferred ownership of ProxyAdmin to:', taskArgs.gnosissafe);
    })

task("upgradeByDefender", "Deploy all base contract")
    .addParam("proxyaddress", "proxy address")
    .addParam("factory", "factory name")
    .setAction(async (taskArgs, hre) => {
        const upgradeFac = await hre.ethers.getContractFactory(taskArgs.factory);
        console.log("Preparing proposal...");
        const proposal = await hre.defender.proposeUpgrade(taskArgs.proxyAddress, upgradeFac);
        console.log("Upgrade proposal created at:", proposal.url);
    })

module.exports = {}
