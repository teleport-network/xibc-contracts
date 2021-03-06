// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../../../libraries/tendermint/MerkleTree.sol";
import "../../../libraries/commitment/Merkle.sol";
import "../../../proto/ProtoBufRuntime.sol";

contract TestMerkleTree {
    function hashFromByteSlices(bytes[] memory data) public pure returns (bytes32) {
        return MerkleTree.hashFromByteSlices(data);
    }

    function verifyMembership(
        bytes memory proofBz,
        bytes[] memory specsBz,
        bytes memory rootBz,
        bytes memory pathBz,
        bytes memory value
    ) public pure {
        ProofSpec.Data[] memory specs = new ProofSpec.Data[](specsBz.length);
        for (uint256 i = 0; i < specsBz.length; i++) {
            specs[i] = ProofSpec.decode(specsBz[i]);
        }
        Merkle.verifyMembership(
            MerkleProof.decode(proofBz),
            specs,
            MerkleRoot.decode(rootBz),
            MerklePath.decode(pathBz),
            value
        );
    }
}
