// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Strings.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/ICrossChain.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Packet is IPacket {
    string public override chainName = "teleport";

    address public constant packetModuleAddress = address(0x7426aFC489D0eeF99a0B438DEF226aD139F75235);
    address public constant crossChainContractAddress = address(0x0000000000000000000000000000000020000002);

    mapping(bytes => uint64) public sequences;
    mapping(bytes => uint8) public ackStatus; // ack state(1 => success, 2 => err, 0 => not found)
    mapping(bytes => PacketTypes.Acknowledgement) public acks;
    mapping(bytes => PacketTypes.Fee) public packetFees; // TBD: delete acked packet fee

    PacketTypes.Packet public latestPacket;

    /**
     * @notice Event triggered when the packet has been sent
     * @param packetBytes packet data
     */
    event PacketSent(bytes packetBytes);

    modifier onlyXIBCModulePacket() {
        require(msg.sender == packetModuleAddress, "caller must be xibc packet module");
        _;
    }

    modifier onlyCrossChainContract() {
        require(msg.sender == crossChainContractAddress, "caller must be xibc app");
        _;
    }

    /**
     * @notice set chain name
     * @param _chainName chain name
     */
    function setChainName(string memory _chainName) public onlyXIBCModulePacket {
        chainName = _chainName;
    }

    /**
     * @notice sendPacket is called by a module in order to send an XIBC packet with single data.
     * @param packet xibc packet
     * @param fee packet fee
     */
    function sendPacket(PacketTypes.Packet memory packet, PacketTypes.Fee memory fee)
        public
        payable
        override
        onlyCrossChainContract
    {
        // should validata packet data in teleport
        // Notice: must sent token to this contract before set packet fee
        packetFees[getCommonUniqueKey(packet.destChain, packet.sequence)] = fee;
        emit PacketSent(abi.encode(packet));
    }

    /**
     * @notice todo
     */
    function onRecvPacket(PacketTypes.Packet memory packet)
        public
        onlyXIBCModulePacket
        returns (
            uint64 code,
            bytes memory result,
            string memory message
        )
    {
        latestPacket = packet;
        try ICrossChain(crossChainContractAddress).onRecvPacket(packet) returns (
            uint64 _code,
            bytes memory _result,
            string memory _message
        ) {
            return (_code, _result, _message);
        } catch {
            return (1, "", "onRecvPacket failed");
        }
    }

    /**
     * @notice todo
     */
    function OnAcknowledgePacket(PacketTypes.Packet memory packet, PacketTypes.Acknowledgement memory ack)
        public
        onlyXIBCModulePacket
    {
        acks[getCommonUniqueKey(packet.destChain, packet.sequence)] = ack;
        ICrossChain(crossChainContractAddress).onAcknowledgementPacket(packet, ack.code, ack.result, ack.message);
    }

    /**
     * @notice set packet fee
     * @param destChain destination chain name
     * @param sequence sequence
     * @param amount add fee amount
     */
    function addPacketFee(
        string memory destChain,
        uint64 sequence,
        uint256 amount
    ) public payable {
        bytes memory key = getCommonUniqueKey(destChain, sequence);

        require(ackStatus[key] == uint8(0), "invalid packet status");

        PacketTypes.Fee memory fee = packetFees[key];

        if (fee.tokenAddress == address(0)) {
            require(msg.value > 0 && msg.value == amount, "invalid value");
        } else {
            require(msg.value == 0, "invalid value");
            require(IERC20(fee.tokenAddress).transferFrom(msg.sender, address(this), amount), "transfer ERC20 failed");
        }

        packetFees[key].amount += amount;
    }

    /**
     * @notice send packet fee to relayer
     * @param destChain destination chain name
     * @param sequence sequence
     * @param relayer relayer address
     */
    function sendPacketFeeToRelayer(
        string calldata destChain,
        uint64 sequence,
        address relayer
    ) external onlyXIBCModulePacket {
        PacketTypes.Fee memory fee = packetFees[getCommonUniqueKey(destChain, sequence)];
        if (fee.tokenAddress == address(0)) {
            payable(relayer).transfer(fee.amount);
        } else {
            require(IERC20(fee.tokenAddress).transfer(relayer, fee.amount), "transfer ERC20 failed");
        }
    }

    /**
     * @notice set current sequence of sourceChain/destChain
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function setSequence(string calldata destChain, uint64 sequence) external onlyXIBCModulePacket {
        bytes memory key = bytes(destChain);
        if (sequence == 2) {
            require(sequences[key] == 0, "invalid sequence");
        } else {
            require(sequences[key] + 1 == sequence, "invalid sequence");
        }
        sequences[key] = sequence;
    }

    /**
     * @notice set ack status
     * @param destChain destination chain name
     * @param sequence sequence
     * @param state is ack state(1 => success, 2 => err, 0 => not found)
     */
    function setAckStatus(
        string calldata destChain,
        uint64 sequence,
        uint8 state
    ) external onlyXIBCModulePacket {
        ackStatus[getCommonUniqueKey(destChain, sequence)] = state;
    }

    /**
     * @notice get packet next sequence to send
     * @param destChain name of destination chain
     */
    function getNextSequenceSend(string memory destChain) public view override returns (uint64) {
        uint64 seq = sequences[bytes(destChain)];
        if (seq == 0) {
            seq = 1;
        }
        return seq;
    }

    /**
     * @notice get ack status
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function getAckStatus(string calldata destChain, uint64 sequence) external view override returns (uint8) {
        return ackStatus[getCommonUniqueKey(destChain, sequence)];
    }

    /**
     * @notice get common unique key
     * @param chain chain name
     * @param sequence sequence
     */
    function getCommonUniqueKey(string memory chain, uint64 sequence) public pure returns (bytes memory) {
        return bytes(Strings.strConcat(Strings.strConcat(chain, "/"), Strings.uint642str(sequence)));
    }

    /**
     * @notice todo
     */
    function getLatestPacket() external view override returns (PacketTypes.Packet memory packet) {
        return latestPacket;
    }
}
