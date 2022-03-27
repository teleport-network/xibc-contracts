// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../interfaces/IPacket.sol";
import "../libraries/core/Packet.sol";
import "../libraries/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Packet is IPacket {
    address public constant packetModuleAddress =
        address(0x7426aFC489D0eeF99a0B438DEF226aD139F75235);
    address public constant transferContractAddress =
        address(0x0000000000000000000000000000000030000001);
    address public constant rccContractAddress =
        address(0x0000000000000000000000000000000030000002);
    address public constant multiCallContractAddress =
        address(0x0000000000000000000000000000000030000003);

    mapping(bytes => uint64) public sequences;
    mapping(bytes => uint8) public ackStatus; // ack state(1 => success, 2 => err, 0 => not found)
    mapping(bytes => PacketTypes.Fee) public packetFees; // TBD: delete acked packet fee

    modifier onlyXIBCModulePacket() {
        require(
            msg.sender == address(packetModuleAddress),
            "caller must be xibc packet module"
        );
        _;
    }

    modifier onlyXIBCAPP() {
        require(
            msg.sender == transferContractAddress ||
                msg.sender == rccContractAddress ||
                msg.sender == multiCallContractAddress,
            "caller must be xibc app"
        );
        _;
    }

    /**
     * @notice set packet fee
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     * @param fee packet fee
     */
    function setPacketFee(
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence,
        PacketTypes.Fee calldata fee
    ) external payable override onlyXIBCAPP {
        // Notice: must sent token to this contract before set packet fee
        packetFees[getAckStatusKey(sourceChain, destChain, sequence)] = fee;
    }

    /**
     * @notice sned packet fee to relayer
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     * @param relayer relayer address
     */
    function snedPacketFeeToRelayer(
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
            require(IERC20(fee.tokenAddress).transfer(relayer, fee.amount), "");
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
        sequences[getNextSequenceSendKey(sourceChain, destChain)] = sequence;
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
                    "nextSequenceSend/",
                    Strings.strConcat(
                        Strings.strConcat(sourceChain, "/"),
                        destChain
                    )
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
                    "ackStatus/",
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
                )
            );
    }
}
