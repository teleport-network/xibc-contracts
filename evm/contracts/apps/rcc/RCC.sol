// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../proto/Ack.sol";
import "../../proto/RemoteContractCall.sol";
import "../../core/client/ClientManager.sol";
import "../../libraries/app/RCC.sol";
import "../../libraries/packet/Packet.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IRCC.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RCC is Initializable, IRCC, OwnableUpgradeable {
    using Strings for *;
    using Bytes for *;

    bytes32 public constant MULTISEND_ROLE = keccak256("MULTISEND_ROLE");

    string private constant PORT = "CONTRACT";

    IPacket public packet;
    IClientManager public clientManager;
    IAccessManager public accessManager;

    mapping(bytes32 => bytes) public override acks;

    RemoteContractCall.Data public latestPacket;

    event Ack(bytes32 indexed dataHash, bytes ack);

    modifier onlyPacket() {
        require(msg.sender == address(packet), "caller not packet contract");
        _;
    }

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    function initialize(
        address packetContract,
        address clientMgrContract,
        address accessManagerContract
    ) public initializer {
        packet = IPacket(packetContract);
        clientManager = IClientManager(clientMgrContract);
        accessManager = IAccessManager(accessManagerContract);
    }

    function sendRemoteContractCall(RCCDataTypes.RCCData calldata rccData)
        external
        override
    {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(rccData.destChain),
            "sourceChain can't equal to destChain"
        );

        RemoteContractCall.Data memory packetData = RemoteContractCall.Data({
            srcChain: sourceChain,
            destChain: rccData.destChain,
            sender: msg.sender.addressToString(),
            contractAddress: rccData.contractAddress,
            data: rccData.data
        });

        // send packet
        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;
        dataList[0] = RemoteContractCall.encode(packetData);
        PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
            sequence: packet.getNextSequenceSend(
                sourceChain,
                rccData.destChain
            ),
            sourceChain: sourceChain,
            destChain: rccData.destChain,
            relayChain: rccData.relayChain,
            ports: ports,
            dataList: dataList
        });
        packet.sendPacket(crossPacket);
    }

    function remoteContractCall(RCCDataTypes.RCCDataMulti calldata rccData)
        external
        override
        onlyAuthorizee(MULTISEND_ROLE)
        returns (bytes memory)
    {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(rccData.destChain),
            "sourceChain can't equal to destChain"
        );

        RemoteContractCall.Data memory packetData = RemoteContractCall.Data({
            srcChain: sourceChain,
            destChain: rccData.destChain,
            sender: rccData.sender.addressToString(),
            contractAddress: rccData.contractAddress,
            data: rccData.data
        });

        return RemoteContractCall.encode(packetData);
    }

    // ===========================================================================

    function onRecvPacket(bytes calldata data)
        external
        override
        onlyPacket
        returns (PacketTypes.Result memory)
    {
        RemoteContractCall.Data memory packetData = RemoteContractCall.decode(
            data
        );

        require(
            packetData.contractAddress.parseAddr() != address(this),
            "illegal operation"
        );

        require(
            packetData.contractAddress.parseAddr() != address(packet),
            "illegal operation"
        );

        latestPacket = packetData;

        PacketTypes.Result memory result;
        (bool success, bytes memory res) = packetData
            .contractAddress
            .parseAddr()
            .call(packetData.data);
        if (!success) {
            result.message = "onRecvPackt: execute packet failed";
        } else if (res.length == 0) {
            result.result = hex"01";
        } else {
            result.result = res;
        }

        return result;
    }

    function onAcknowledgementPacket(bytes calldata data, bytes calldata result)
        external
        override
        onlyPacket
    {
        acks[sha256(data)] = result;
        emit Ack(sha256(data), result);
    }

    // ===========================================================================

    function getLatestPacket()
        external
        view
        override
        returns (RemoteContractCall.Data memory)
    {
        return latestPacket;
    }
}
