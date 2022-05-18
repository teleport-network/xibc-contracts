// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../interfaces/IPacket.sol";
import "../../interfaces/ICrossChain.sol";
import "../../libraries/packet/Packet.sol";
import "../../libraries/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Packet is IPacket {
    address public constant packetModuleAddress =
        address(0x7426aFC489D0eeF99a0B438DEF226aD139F75235);
    address public constant crossChainContractAddress =
        address(0x0000000000000000000000000000000020000002);

    mapping(bytes => uint64) public sequences;
    mapping(bytes => uint8) public ackStatus; // ack state(1 => success, 2 => err, 0 => not found)
    mapping(bytes => PacketTypes.Fee) public packetFees; // TBD: delete acked packet fee

    PacketTypes.PacketData public latestPacketData;

    /**
     * @notice Event triggered when the packet has been sent
     * @param packet packet data
     */
    event PacketSent(PacketTypes.Packet packet);

    modifier onlyXIBCModulePacket() {
        require(
            msg.sender == packetModuleAddress,
            "caller must be xibc packet module"
        );
        _;
    }

    modifier onlyCrossChainContract() {
        require(
            msg.sender == crossChainContractAddress,
            "caller must be xibc app"
        );
        _;
    }

    function sendPacket(
        PacketTypes.PacketData memory packetData,
        PacketTypes.Fee memory fee
    ) public payable override onlyCrossChainContract {
        // should validata packet data in teleport
        // Notice: must sent token to this contract before set packet fee
        packetFees[
            getAckStatusKey(
                packetData.srcChain,
                packetData.destChain,
                packetData.sequence
            )
        ] = fee;
        emit PacketSent(PacketTypes.Packet({data: abi.encode(packetData)}));
    }

    /**
     * @notice todo
     */
    function onRecvPacket(PacketTypes.PacketData calldata packetData)
        external
        onlyXIBCModulePacket
        returns (
            uint64 code,
            bytes memory result,
            string memory message
        )
    {
        latestPacketData = packetData;
        try
            ICrossChain(crossChainContractAddress).onRecvPacket(packetData)
        returns (uint64 _code, bytes memory _result, string memory _message) {
            return (_code, _result, _message);
        } catch (bytes memory _res) {
            return (1, "", string(_res));
        }
    }

    /**
     * @notice todo
     */
    function OnAcknowledgePacket(
        PacketTypes.PacketData calldata packetData,
        PacketTypes.Acknowledgement calldata ack
    ) external onlyXIBCModulePacket {
        ICrossChain(crossChainContractAddress).onAcknowledgementPacket(
            packetData,
            ack.code,
            ack.result,
            ack.message
        );
    }

    /**
     * @notice set packet fee
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     * @param amount add fee amount
     */
    function addPacketFee(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence,
        uint256 amount
    ) public payable {
        bytes memory key = getAckStatusKey(sourceChain, destChain, sequence);

        require(ackStatus[key] == uint8(0), "invalid packet status");

        PacketTypes.Fee memory fee = packetFees[key];

        if (fee.tokenAddress == address(0)) {
            require(msg.value > 0 && msg.value == amount, "invalid value");
        } else {
            require(msg.value == 0, "invalid value");
            require(
                IERC20(fee.tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                ),
                "transfer ERC20 failed"
            );
        }

        packetFees[key].amount += amount;
    }

    /**
     * @notice send packet fee to relayer
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     * @param relayer relayer address
     */
    function sendPacketFeeToRelayer(
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence,
        address relayer
    ) external onlyXIBCModulePacket {
        PacketTypes.Fee memory fee = packetFees[
            getAckStatusKey(sourceChain, destChain, sequence)
        ];
        if (fee.tokenAddress == address(0)) {
            payable(relayer).transfer(fee.amount);
        } else {
            require(
                IERC20(fee.tokenAddress).transfer(relayer, fee.amount),
                "transfer ERC20 failed"
            );
        }
    }

    /**
     * @notice set current sequence of sourceChain/destChain
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function setSequence(
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence
    ) external onlyXIBCModulePacket {
        bytes memory key = getNextSequenceSendKey(sourceChain, destChain);
        if (sequence == 2) {
            require(sequences[key] == 0, "invalid sequence");
        } else {
            require(sequences[key] + 1 == sequence, "invalid sequence");
        }
        sequences[key] = sequence;
    }

    /**
     * @notice set ack status
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     * @param state is ack state(1 => success, 2 => err, 0 => not found)
     */
    function setAckStatus(
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence,
        uint8 state
    ) external onlyXIBCModulePacket {
        ackStatus[getAckStatusKey(sourceChain, destChain, sequence)] = state;
    }

    /**
     * @notice get packet next sequence to send
     * @param sourceChain name of source chain
     * @param destChain name of destination chain
     */
    function getNextSequenceSend(
        string memory sourceChain,
        string memory destChain
    ) public view override returns (uint64) {
        uint64 seq = sequences[getNextSequenceSendKey(sourceChain, destChain)];
        if (seq == 0) {
            seq = 1;
        }
        return seq;
    }

    /**
     * @notice get ack status
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function getAckStatus(
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence
    ) external view override returns (uint8) {
        return ackStatus[getAckStatusKey(sourceChain, destChain, sequence)];
    }

    /**
     * @notice get packet next sequence to send
     * @param sourceChain name of source chain
     * @param destChain name of destination chain
     */
    function getNextSequenceSendKey(
        string memory sourceChain,
        string memory destChain
    ) internal pure returns (bytes memory) {
        return
            bytes(
                Strings.strConcat(
                    Strings.strConcat(sourceChain, "/"),
                    destChain
                )
            );
    }

    /**
     * @notice get ack status key
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function getAckStatusKey(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return
            bytes(
                Strings.strConcat(
                    Strings.strConcat(
                        Strings.strConcat(
                            Strings.strConcat(sourceChain, "/"),
                            destChain
                        ),
                        "/"
                    ),
                    Strings.uint642str(sequence)
                )
            );
    }

    /**
     * @notice todo
     */
    function getLatestPacketData()
        external
        view
        override
        returns (PacketTypes.PacketData memory packetData)
    {
        return latestPacketData;
    }
}
