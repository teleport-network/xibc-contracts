// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../../../../../libraries/tendermint/LightClient.sol";

library LightClientVerify {
    function verify(
        SignedHeader.Data memory trustedHeader,
        ValidatorSet.Data memory trustedVals,
        SignedHeader.Data memory untrustedHeader,
        ValidatorSet.Data memory untrustedVals,
        int64 trustingPeriod,
        Timestamp.Data memory nowTime,
        int64 maxClockDrift,
        Fraction.Data memory trustLevel
    ) public pure {
        LightClient.verify(
            trustedHeader,
            trustedVals,
            untrustedHeader,
            untrustedVals,
            trustingPeriod,
            nowTime,
            maxClockDrift,
            trustLevel
        );
    }
}

library LightClientGenValHash {
    function genValidatorSetHash(ValidatorSet.Data memory vals) public pure returns (bytes memory) {
        return LightClient.genValidatorSetHash(vals);
    }
}
