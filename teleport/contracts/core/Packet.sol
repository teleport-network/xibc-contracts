// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../interfaces/IPacket.sol";
import "../libraries/utils/Strings.sol";

contract Packet is IPacket {
    address public constant xibcModulePackert =
        address(0x7426aFC489D0eeF99a0B438DEF226aD139F75235);

    mapping(bytes => uint64) public sequences;
    mapping(bytes => bool) public ackStatus;

    modifier onlyXIBCModulePacket() {
        require(
            msg.sender == address(xibcModulePackert),
            "caller must be xibc packet module"
        );
        _;
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
     * @param successed is successed
     */
    function setAckStatus(
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence,
        bool successed
    ) external onlyXIBCModulePacket {
        ackStatus[
            getAckStatusKey(sourceChain, destChain, sequence)
        ] = successed;
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
    ) external view override returns (bool) {
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
