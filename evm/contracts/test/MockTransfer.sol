// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../proto/TokenTransfer.sol";
import "../proto/Ack.sol";
import "../core/client/ClientManager.sol";
import "../libraries/packet/Packet.sol";
import "../libraries/app/Transfer.sol";
import "../libraries/utils/Bytes.sol";
import "../libraries/utils/Strings.sol";
import "../interfaces/IPacket.sol";
import "../interfaces/ITransfer.sol";
import "../interfaces/IERC20XIBC.sol";
import "../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTransfer is Initializable, ITransfer, OwnableUpgradeable {
    using Strings for *;
    using Bytes for *;

    bytes32 public constant BIND_TOKEN_ROLE = keccak256("BIND_TOKEN_ROLE");

    string private constant PORT = "FT";

    IPacket public packet;
    IClientManager public clientManager;
    IAccessManager public accessManager;

    TokenTransfer.Data public latestPacket;

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

    function bindToken(
        address tokenAddres,
        string calldata oriToken,
        string calldata oriChain
    ) external onlyAuthorizee(BIND_TOKEN_ROLE) {}

    function sendTransferERC20(
        TransferDataTypes.ERC20TransferData calldata transferData
    ) external override {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        // send packet
        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;
        dataList[0] = bytes("testdata");
        PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
            sequence: packet.getNextSequenceSend(
                sourceChain,
                transferData.destChain
            ),
            sourceChain: sourceChain,
            destChain: transferData.destChain,
            relayChain: transferData.relayChain,
            ports: ports,
            dataList: dataList
        });
        packet.sendPacket(crossPacket);
    }

    function sendTransferBase(
        TransferDataTypes.BaseTransferData calldata transferData
    ) external payable override {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't be equal to destChain"
        );

        require(msg.value > 0, "value must be greater than 0");
        // send packet
        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;
        dataList[0] = bytes("testdata");
        PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
            sequence: packet.getNextSequenceSend(
                sourceChain,
                transferData.destChain
            ),
            sourceChain: sourceChain,
            destChain: transferData.destChain,
            relayChain: transferData.relayChain,
            ports: ports,
            dataList: dataList
        });
        packet.sendPacket(crossPacket);
    }

    function onRecvPacket(bytes calldata data)
        external
        override
        onlyPacket
        returns (PacketTypes.Result memory)
    {
        if (data.length != 0) {
            return _newAcknowledgement(true, "");
        }
        return _newAcknowledgement(false, "error");
    }

    function onAcknowledgementPacket(bytes calldata data, bytes calldata result)
        external
        override
        onlyPacket
    {}

    function _newAcknowledgement(bool success, string memory errMsg)
        private
        pure
        returns (PacketTypes.Result memory)
    {
        PacketTypes.Result memory result;
        if (success) {
            result.result = hex"01";
        } else {
            result.message = errMsg;
        }
        return result;
    }

    function NewAcknowledgement(bool success, string memory errMsg)
        public
        pure
        returns (bytes memory)
    {
        bytes[] memory results = new bytes[](1);
        results[0] = hex"01";

        Acknowledgement.Data memory data;
        if (success) {
            data.results = results;
        } else {
            data.message = errMsg;
        }

        return Acknowledgement.encode(data);
    }

    function transferERC20(
        TransferDataTypes.ERC20TransferDataMulti calldata transferData
    ) external override returns (bytes memory) {}

    function transferBase(
        TransferDataTypes.BaseTransferDataMulti calldata transferData
    ) external payable override returns (bytes memory) {}
}
