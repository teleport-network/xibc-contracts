// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../proto/Types.sol";
import "../../proto/Validator.sol";
import "../../proto/ProtoBufRuntime.sol";
import "../../proto/Tendermint.sol";
import "../utils/Timestamp.sol";
import "../utils/Bytes.sol";
import "../utils/Ed25519.sol";
import "./MerkleTree.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

library LightClient {
    using TimestampLib for Timestamp.Data;

    /**
     *  @notice this function combines both VerifyAdjacent and VerifyNonAdjacent functions.
     *  @param trustedHeader      trusted header
     *  @param trustedVals        trusted validatorSet
     *  @param untrustedHeader    header that needs to be verified
     *  @param untrustedVals      validatorSet that needs to be verified
     *  @param trustingPeriod     trust period of client state
     *  @param nowTime            current time (block.timestamp)
     *  @param maxClockDrift      max clock drift
     *  @param trustLevel         threshold for signature verification
     */
    function verify(
        SignedHeader.Data memory trustedHeader,
        ValidatorSet.Data memory trustedVals,
        SignedHeader.Data memory untrustedHeader,
        ValidatorSet.Data memory untrustedVals,
        int64 trustingPeriod,
        Timestamp.Data memory nowTime,
        int64 maxClockDrift,
        Fraction.Data memory trustLevel
    ) internal pure {
        if (trustedHeader.header.height + 1 != untrustedHeader.header.height) {
            verifyNonAdjacent(
                trustedHeader,
                trustedVals,
                untrustedHeader,
                untrustedVals,
                trustingPeriod,
                nowTime,
                maxClockDrift,
                trustLevel
            );
            return;
        }
        verifyAdjacent(trustedHeader, untrustedHeader, untrustedVals, trustingPeriod, nowTime, maxClockDrift);
    }

    /**
     * @notice this function verifies non-adjacent untrustedHeader against
    trustedHeader. It ensures that:
    
    	a) trustedHeader can still be trusted (if not, ErrOldHeaderExpired is returned)
    	b) untrustedHeader is valid (if not, ErrInvalidHeader is returned)
    	c) trustLevel ([1/3, 1]) of trustedHeaderVals (or trustedHeaderNextVals)
     signed correctly (if not, ErrNewValSetCantBeTrusted is returned)
    	d) more than 2/3 of untrustedVals have signed h2
       (otherwise, ErrInvalidHeader is returned)
     e) headers are non-adjacent.
    
        maxClockDrift defines how much untrustedHeader.Time can drift into the
        future.
     */
    function verifyNonAdjacent(
        SignedHeader.Data memory trustedHeader,
        ValidatorSet.Data memory trustedVals,
        SignedHeader.Data memory untrustedHeader,
        ValidatorSet.Data memory untrustedVals,
        int64 trustingPeriod,
        Timestamp.Data memory nowTime,
        int64 maxClockDrift,
        Fraction.Data memory trustLevel
    ) internal pure {
        require(untrustedHeader.header.height != trustedHeader.header.height + 1, "headers must be adjacent in height");

        verifyHeaderExpired(trustedHeader.header.time, trustingPeriod, nowTime);
        verifyNewHeaderAndVals(untrustedHeader, untrustedVals, trustedHeader, nowTime, maxClockDrift);

        // Ensure that +`trustLevel` (default 1/3) or more of last trusted validators signed correctly.
        verifyCommitLightTrusting(trustedHeader.header.chain_id, untrustedHeader.commit, trustedVals, trustLevel);
        // Ensure that +2/3 of new validators signed correctly.
        //
        // NOTE: this should always be the last check because untrustedVals can be
        // intentionally made very large to DOS the light client. not the case for
        // VerifyAdjacent, where validator set is known in advance.
        verifyCommitLight(
            trustedHeader.header.chain_id,
            untrustedHeader.header.height,
            untrustedHeader.commit,
            untrustedVals
        );
    }

    /** @notice this function verifies directly adjacent untrustedHeader against
    trustedHeader. It ensures that:
    
     a) trustedHeader can still be trusted (if not, ErrOldHeaderExpired is returned)
     b) untrustedHeader is valid (if not, ErrInvalidHeader is returned)
     c) untrustedHeader.ValidatorsHash equals trustedHeader.NextValidatorsHash
     d) more than 2/3 of new validators (untrustedVals) have signed h2
       (otherwise, ErrInvalidHeader is returned)
     e) headers are adjacent.
    
    maxClockDrift defines how much untrustedHeader.Time can drift into the
    future.
     */
    function verifyAdjacent(
        SignedHeader.Data memory trustedHeader,
        SignedHeader.Data memory untrustedHeader,
        ValidatorSet.Data memory untrustedVals,
        int64 trustingPeriod,
        Timestamp.Data memory nowTime,
        int64 maxClockDrift
    ) internal pure {
        require(untrustedHeader.header.height == trustedHeader.header.height + 1, "headers must be adjacent in height");

        verifyHeaderExpired(trustedHeader.header.time, trustingPeriod, nowTime);
        verifyNewHeaderAndVals(untrustedHeader, untrustedVals, trustedHeader, nowTime, maxClockDrift);

        require(
            Bytes.equals(untrustedHeader.header.validators_hash, trustedHeader.header.next_validators_hash),
            "header next validators not match"
        );

        // Ensure that +2/3 of new validators signed correctly.
        //
        // NOTE: this should always be the last check because untrustedVals can be
        // intentionally made very large to DOS the light client. not the case for
        // VerifyAdjacent, where validator set is known in advance.
        verifyCommitLight(
            trustedHeader.header.chain_id,
            untrustedHeader.header.height,
            untrustedHeader.commit,
            untrustedVals
        );
    }

    /** @notice this function verifies +2/3 of the set had signed the given commit.
    
    This method is primarily used by the light client and does not check all the
    signatures.
     */
    function verifyCommitLight(
        string memory chainID,
        int64 height,
        Commit.Data memory commit,
        ValidatorSet.Data memory untrustedVals
    ) internal pure {
        require(untrustedVals.validators.length == commit.signatures.length, "invalid commit -- wrong set size");

        require(height == commit.height, "Invalid commit -- wrong height");

        int64 talliedVotingPower = 0;
        int64 votingPowerNeeded = (untrustedVals.total_voting_power * 2) / 3;
        for (uint256 i = 0; i < commit.signatures.length; i++) {
            if (commit.signatures[i].block_id_flag != TYPES_PROTO_GLOBAL_ENUMS.BlockIDFlag.BLOCK_ID_FLAG_COMMIT) {
                continue;
            }
            // The vals and commit have a 1-to-1 correspondance.
            // This means we don't need the validator address or to do any lookup.
            Validator.Data memory val = untrustedVals.validators[i];
            // Validate signature.
            bytes memory signBytes = genVoteSignBytes(commit, chainID, i);
            Ed25519.verify(
                Bytes.toBytes32(val.pub_key.ed25519),
                Bytes.toBytes32(Bytes.substr(commit.signatures[i].signature, 0, 32)),
                Bytes.toBytes32(Bytes.substr(commit.signatures[i].signature, 32, 32)),
                signBytes
            );
            talliedVotingPower += val.voting_power;
            // return as soon as +2/3 of the signatures are verified
            if (talliedVotingPower > votingPowerNeeded) {
                return;
            }
        }
        revert("verifyCommitLight: invalid commit -- insufficient voting power");
    }

    /**
     * @notice VerifyCommitLightTrusting verifies that trustLevel of the validator set signed
        this commit.
        
        the given validators do not necessarily correspond to the validator set
        for this commit, but there may be some intersection.
        
        This method is primarily used by the light client and does not check all the
        signatures.
     *  @param chainID           chain id.
     *  @param commit            block voting information.
     *  @param trustedValset     trusted validatorSet.
     *  @param trustLevel        threshold for signature verification.
     *  
     */
    function verifyCommitLightTrusting(
        string memory chainID,
        Commit.Data memory commit,
        ValidatorSet.Data memory trustedValset,
        Fraction.Data memory trustLevel
    ) internal pure {
        require(trustLevel.denominator != 0, "trustLevel has zero Denominator");

        uint256 totalVotingPower;
        for (uint256 i = 0; i < trustedValset.validators.length; i++) {
            totalVotingPower += uint256(trustedValset.validators[i].voting_power);
        }

        (bool success, uint256 totalVotingPowerMulByNumerator) = SafeMath.tryMul(
            totalVotingPower,
            uint256(trustLevel.numerator)
        );
        require(
            success,
            "uint256 overflow while calculating voting power needed. please provide smaller trustLevel numerator"
        );

        uint256 talliedVotingPower = 0;
        uint256 votingPowerNeeded = uint256(totalVotingPowerMulByNumerator) / uint256(trustLevel.denominator);

        for (uint256 i = 0; i < commit.signatures.length; i++) {
            if (commit.signatures[i].block_id_flag != TYPES_PROTO_GLOBAL_ENUMS.BlockIDFlag.BLOCK_ID_FLAG_COMMIT) {
                continue;
            }

            // The vals and commit have a 1-to-1 correspondance.
            // This means we don't need the validator address or to do any lookup.
            Validator.Data memory val = trustedValset.validators[i];

            if (contains(i, val.addr, commit.signatures)) {
                revert("commit double vote");
            }

            // Validate signature.
            bytes memory signBytes = genVoteSignBytes(commit, chainID, i);
            Ed25519.verify(
                Bytes.toBytes32(val.pub_key.ed25519),
                Bytes.toBytes32(Bytes.substr(commit.signatures[i].signature, 0, 32)),
                Bytes.toBytes32(Bytes.substr(commit.signatures[i].signature, 32, 32)),
                signBytes
            );
            talliedVotingPower += uint256(val.voting_power);
            if (talliedVotingPower > votingPowerNeeded) {
                return;
            }
        }
        revert("verifyCommitLightTrusting: invalid commit -- insufficient voting power");
    }

    /** @notice this function verifies the new header and new validator set.
     *  @param untrustedHeader   header of the block that is being committed.
     *  @param untrustedVals     validator set of the block that is being committed.
     *  @param trustedHeader     trusted header.
     *  @param nowTime           the current time.
     *  @param maxClockDrift     max clock drift.
     */
    function verifyNewHeaderAndVals(
        SignedHeader.Data memory untrustedHeader,
        ValidatorSet.Data memory untrustedVals,
        SignedHeader.Data memory trustedHeader,
        Timestamp.Data memory nowTime,
        int64 maxClockDrift
    ) internal pure {
        // validate header hash
        require(
            Bytes.equals(genHeaderHash(untrustedHeader.header), untrustedHeader.commit.block_id.hash),
            "invalid header hash"
        );

        require(
            untrustedHeader.header.height > trustedHeader.header.height,
            "expected new header height to be greater than one of old header"
        );

        require(
            untrustedHeader.header.time.greaterThan(trustedHeader.header.time),
            "expected new header time to be after old header time"
        );

        Timestamp.Data memory localTime = nowTime.add(maxClockDrift);
        require(untrustedHeader.header.time.lessThan(localTime), "new header has a time from the future");

        bytes memory valHash = genValidatorSetHash(untrustedVals);
        require(Bytes.equals(valHash, untrustedHeader.header.validators_hash), "invalid validator set hash");
    }

    /** @notice this function verifies that the given header is expired.
     *  @param lastTrustTime      the time when the header was last trusted.
     *  @param trustingPeriod     the trusting period.
     *  @param nowTime            the current time.
     */
    function verifyHeaderExpired(
        Timestamp.Data memory lastTrustTime,
        int64 trustingPeriod,
        Timestamp.Data memory nowTime
    ) internal pure {
        Timestamp.Data memory expirationTime = lastTrustTime.add(trustingPeriod);
        require(expirationTime.greaterThan(nowTime), "Header expired");
    }

    function genVoteSignBytes(
        Commit.Data memory commit,
        string memory chainID,
        uint256 idx
    ) internal pure returns (bytes memory) {
        CommitSig.Data memory sig = commit.signatures[idx];
        CanonicalVote.Data memory vote;
        vote.typ = TYPES_PROTO_GLOBAL_ENUMS.SignedMsgType.SIGNED_MSG_TYPE_PRECOMMIT;
        vote.height = commit.height;
        vote.round = commit.round;
        vote.block_id.hash = commit.block_id.hash;
        vote.block_id.part_set_header.total = commit.block_id.part_set_header.total;
        vote.block_id.part_set_header.hash = commit.block_id.part_set_header.hash;
        vote.timestamp = sig.timestamp;
        vote.chain_id = chainID;
        return CanonicalVote.encode(vote);
    }

    function encode_string(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = new bytes(ProtoBufRuntime._sz_lendelim(bytes(s).length));
        uint256 sz = ProtoBufRuntime._encode_string(s, 33, ss) + 1;
        assembly {
            mstore(ss, sz)
        }
        ss[0] = 0x0a;
        return ss;
    }

    function encode_int64(int64 i) internal pure returns (bytes memory) {
        bytes memory ii = new bytes(ProtoBufRuntime._sz_int64(i));
        uint256 sz = ProtoBufRuntime._encode_int64(i, 33, ii) + 1;
        assembly {
            mstore(ii, sz)
        }
        ii[0] = 0x08;
        return ii;
    }

    function encode_bytes(bytes memory b) internal pure returns (bytes memory) {
        bytes memory bb = new bytes(ProtoBufRuntime._sz_lendelim(b.length));
        uint256 sz = ProtoBufRuntime._encode_bytes(b, 33, bb) + 1;
        assembly {
            mstore(bb, sz)
        }
        bb[0] = 0x0a;
        return bb;
    }

    function genHeaderHash(TmHeader.Data memory header) internal pure returns (bytes memory) {
        bytes[] memory valsBz = new bytes[](14);
        valsBz[0] = Consensus.encode(header.version);
        valsBz[1] = encode_string(header.chain_id);
        valsBz[2] = encode_int64(header.height);
        valsBz[3] = Timestamp.encode(header.time);
        valsBz[4] = BlockID.encode(header.last_block_id);
        valsBz[5] = encode_bytes(header.last_commit_hash);
        valsBz[6] = encode_bytes(header.data_hash);
        valsBz[7] = encode_bytes(header.validators_hash);
        valsBz[8] = encode_bytes(header.next_validators_hash);
        valsBz[9] = encode_bytes(header.consensus_hash);
        valsBz[10] = encode_bytes(header.app_hash);
        valsBz[11] = encode_bytes(header.last_results_hash);
        valsBz[12] = encode_bytes(header.evidence_hash);
        valsBz[13] = encode_bytes(header.proposer_address);
        return Bytes.fromBytes32(MerkleTree.hashFromByteSlices(valsBz));
    }

    function genValidatorSetHash(ValidatorSet.Data memory vals) internal pure returns (bytes memory) {
        bytes[] memory valsBz = new bytes[](vals.validators.length);
        for (uint256 i = 0; i < vals.validators.length; i++) {
            SimpleValidator.Data memory val;
            val.pub_key = vals.validators[i].pub_key;
            val.voting_power = vals.validators[i].voting_power;

            valsBz[i] = SimpleValidator.encode(val);
        }
        return Bytes.fromBytes32(MerkleTree.hashFromByteSlices(valsBz));
    }

    function contains(
        uint256 beginIdx,
        bytes memory ele,
        CommitSig.Data[] memory sigs
    ) internal pure returns (bool) {
        for (uint256 i = beginIdx + 1; i < sigs.length; i++) {
            if (Bytes.equals(sigs[i].signature, ele)) {
                return true;
            }
        }
        return false;
    }
}
