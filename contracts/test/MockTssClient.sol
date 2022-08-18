// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../interfaces/IClient.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TssClient is Initializable, IClient, OwnableUpgradeable {
    // clientManager contract address
    address clientManager;

    modifier onlyClientManager() {
        require(msg.sender == clientManager, "caller not client manager contract");
        _;
    }

    function initialize(address clientManagerAddr) public initializer {
        clientManager = clientManagerAddr;
    }

    function getClientType() external view override returns (IClient.Type) {
        return IClient.Type.TSS;
    }

    function getLatestHeight() external view override returns (Height.Data memory) {
        return Height.Data(0, 0);
    }

    function status() external view override returns (Status) {
        return Status.Active;
    }

    function initializeState(bytes calldata clientStateBz, bytes calldata) external override onlyClientManager {}

    function upgrade(
        address,
        bytes calldata clientStateBz,
        bytes calldata
    ) external override onlyClientManager {}

    function checkHeaderAndUpdateState(address, bytes calldata headerBz) external override onlyClientManager {}

    function verifyPacketCommitment(
        address caller,
        Height.Data calldata,
        bytes calldata,
        string calldata,
        string calldata,
        uint64,
        bytes calldata
    ) external view override {}

    function verifyPacketAcknowledgement(
        address caller,
        Height.Data calldata,
        bytes calldata,
        string calldata,
        string calldata,
        uint64,
        bytes calldata
    ) external view override {}
}
