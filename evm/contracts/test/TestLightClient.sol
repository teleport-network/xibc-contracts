// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/tendermint/LightClient.sol";
import "../proto/Validator.sol";
import "../proto/Tendermint.sol";
import "../clients/light-clients/tendermint/Codec.sol";

contract TestLightClient {
    function genValidatorSetHash(bytes memory data)
        public
        pure
        returns (bytes memory)
    {
        ValidatorSet.Data memory set = ValidatorSet.decode(data);
        return LightClient.genValidatorSetHash(set);
    }

    function genHeaderHash(bytes memory data)
        public
        pure
        returns (bytes memory)
    {
        Header.Data memory header = HeaderCodec.decode(data);
        return LightClient.genHeaderHash(header.signed_header.header);
    }
}
