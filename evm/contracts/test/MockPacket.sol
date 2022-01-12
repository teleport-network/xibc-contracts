// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../core/client/ClientManager.sol";
import "../proto/Ack.sol";
import "../proto/Types.sol";
import "../libraries/client/Client.sol";
import "../libraries/packet/Packet.sol";
import "../libraries/host/Host.sol";
import "../interfaces/IClientManager.sol";
import "../interfaces/IClient.sol";
import "../interfaces/IModule.sol";
import "../interfaces/IPacket.sol";
import "../interfaces/IRouting.sol";
import "../interfaces/IAccessManager.sol";

contract MockPacket is Initializable, OwnableUpgradeable, IPacket {
    using Strings for *;

    IModule private module;

    function setModule(IModule _module) public {
        module = _module;
    }

    function sendPacket(PacketTypes.Packet calldata packet) external override {}

    function sendMultiPacket(PacketTypes.Packet calldata packet)
        external
        override
    {}

    function recvPacket(
        PacketTypes.Packet calldata packet,
        bytes calldata proof,
        Height.Data calldata height
    ) external override {
        Acknowledgement.Data memory ack;
        try this.executePacket(packet) returns (bytes[] memory results) {
            ack.results = results;
        } catch Error(string memory message) {
            ack.message = message;
        }
    }

    function executePacket(PacketTypes.Packet calldata packet)
        external
        returns (bytes[] memory)
    {
        bytes[] memory results = new bytes[](packet.ports.length);
        for (uint64 i = 0; i < packet.ports.length; i++) {
            PacketTypes.Result memory res = module.onRecvPacket(
                packet.dataList[i]
            );
            require(
                res.result.length > 0,
                Strings
                    .uint642str(i)
                    .toSlice()
                    .concat(": ".toSlice())
                    .toSlice()
                    .concat(res.message.toSlice())
            );
            results[i] = res.result;
        }
        return results;
    }

    function acknowledgePacket(
        PacketTypes.Packet calldata packet,
        bytes calldata acknowledgement,
        bytes calldata proofAcked,
        Height.Data calldata height
    ) external override {}

    function getNextSequenceSend(
        string calldata sourceChain,
        string calldata destChain
    ) external view override returns (uint64) {}
}
