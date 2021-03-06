// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "./Proof.sol";
import "../../proto/Proofs.sol";
import "../../proto/Commitment.sol";

library Compress {
    function decompress(CommitmentProof.Data memory proof) internal pure returns (CommitmentProof.Data memory pf) {
        if (proof.compressed.entries.length == 0) {
            return proof;
        }
        pf.batch = decompressBatch(proof.compressed);
        return pf;
    }

    function decompressBatch(CompressedBatchProof.Data memory comp) internal pure returns (BatchProof.Data memory bpf) {
        BatchEntry.Data[] memory entries = new BatchEntry.Data[](comp.entries.length);
        for (uint256 i = 0; i < comp.entries.length; i++) {
            entries[i] = decompressEntry(comp.entries[i], comp.lookup_inners);
        }
        bpf.entries = entries;
    }

    function decompressEntry(CompressedBatchEntry.Data memory entry, InnerOp.Data[] memory lookup)
        internal
        pure
        returns (BatchEntry.Data memory batchEntry)
    {
        if (entry.exist.key.length > 0) {
            batchEntry.exist = decompressExist(entry.exist, lookup);
            return batchEntry;
        }
        batchEntry.nonexist = NonExistenceProof.Data(
            entry.nonexist.key,
            decompressExist(entry.nonexist.left, lookup),
            decompressExist(entry.nonexist.right, lookup)
        );
        return batchEntry;
    }

    function decompressExist(CompressedExistenceProof.Data memory exist, InnerOp.Data[] memory lookup)
        internal
        pure
        returns (ExistenceProof.Data memory epf)
    {
        if (exist.key.length == 0) {
            return epf;
        }
        epf.key = exist.key;
        epf.value = exist.value;
        epf.leaf = exist.leaf;
        epf.path = new InnerOp.Data[](exist.path.length);
        for (uint256 i = 0; i < exist.path.length; i++) {
            epf.path[i] = lookup[i];
        }
    }
}
