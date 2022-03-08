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
                taskArgs.chain,
                accessManager.address.toLocaleLowerCase(),
            ]
        )
        await clientManager.deployed()
        console.log("export CLIENT_MANAGER_ADDRESS=%s", clientManager.address.toLocaleLowerCase())

        const routingFactory = await hre.ethers.getContractFactory('Routing')
        const routing = await hre.upgrades.deployProxy(routingFactory, [accessManager.address.toLocaleLowerCase()])
        await routing.deployed()
        console.log("export ROUTING_ADDRESS=%s", routing.address.toLocaleLowerCase())

        const packetFactory = await hre.ethers.getContractFactory('Packet')
        const packet = await hre.upgrades.deployProxy(
            packetFactory,
            [
                clientManager.address.toLocaleLowerCase(),
                routing.address.toLocaleLowerCase(),
                accessManager.address.toLocaleLowerCase()
            ]
        )
        await packet.deployed()
        console.log("export PACKET_ADDRESS=%s", packet.address.toLocaleLowerCase())

        const transferFactory = await hre.ethers.getContractFactory('Transfer')
        const transfer = await hre.upgrades.deployProxy(
            transferFactory,
            [
                packet.address.toLocaleLowerCase(),
                clientManager.address.toLocaleLowerCase(),
                accessManager.address.toLocaleLowerCase()
            ],
        )
        await transfer.deployed()
        console.log("export TRANSFER_ADDRESS=%s", transfer.address.toLocaleLowerCase())

        const RCCFactory = await hre.ethers.getContractFactory('RCC')
        const rcc = await hre.upgrades.deployProxy(
            RCCFactory,
            [
                packet.address.toLocaleLowerCase(),
                clientManager.address.toLocaleLowerCase(),
                accessManager.address.toLocaleLowerCase()
            ]
        )
        await rcc.deployed()
        console.log("export RCC_ADDRESS=%s", rcc.address.toLocaleLowerCase())

        const multiCallFactory = await hre.ethers.getContractFactory('MultiCall')
        const multiCall = await hre.upgrades.deployProxy(
            multiCallFactory,
            [
                packet.address.toLocaleLowerCase(),
                clientManager.address.toLocaleLowerCase(),
                transfer.address.toLocaleLowerCase(),
                rcc.address.toLocaleLowerCase()
            ]
        )
        await multiCall.deployed()
        console.log("export MULTICALl_ADDRESS=%s", multiCall.address.toLocaleLowerCase())

        const ProxyFactory = await hre.ethers.getContractFactory('Proxy')
        const proxy = await hre.upgrades.deployProxy(
            ProxyFactory,
            [
                clientManager.address.toLocaleLowerCase(),
                multiCall.address.toLocaleLowerCase(),
                packet.address.toLocaleLowerCase(),
                transfer.address.toLocaleLowerCase()
            ]
        )
        await proxy.deployed()
        console.log("export PROXY_ADDRESS=%s", proxy.address.toLocaleLowerCase())
    })

task("transferoOwnership", "Deploy all base contract")
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
