// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
import "./ProtoBufRuntime.sol";
import "./GoogleProtobufAny.sol";

library TokenTransfer {
    //struct definition
    struct Data {
        string srcChain;
        string destChain;
        string sender;
        string receiver;
        bytes amount;
        string token;
        string oriToken;
    }

    // Decoder section

    /**
     * @dev The main decoder for memory
     * @param bs The bytes array to be decoded
     * @return The decoded struct
     */
    function decode(bytes memory bs) internal pure returns (Data memory) {
        (Data memory x, ) = _decode(32, bs, bs.length);
        return x;
    }

    /**
     * @dev The main decoder for storage
     * @param self The in-storage struct
     * @param bs The bytes array to be decoded
     */
    function decode(Data storage self, bytes memory bs) internal {
        (Data memory x, ) = _decode(32, bs, bs.length);
        store(x, self);
    }

    // inner decoder

    /**
     * @dev The decoder for internal usage
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @param sz The number of bytes expected
     * @return The decoded struct
     * @return The number of bytes decoded
     */
    function _decode(
        uint256 p,
        bytes memory bs,
        uint256 sz
    ) internal pure returns (Data memory, uint256) {
        Data memory r;
        uint256[8] memory counters;
        uint256 fieldId;
        ProtoBufRuntime.WireType wireType;
        uint256 bytesRead;
        uint256 offset = p;
        uint256 pointer = p;
        while (pointer < offset + sz) {
            (fieldId, wireType, bytesRead) = ProtoBufRuntime._decode_key(
                pointer,
                bs
            );
            pointer += bytesRead;
            if (fieldId == 1) {
                pointer += _read_srcChain(pointer, bs, r, counters);
            } else if (fieldId == 2) {
                pointer += _read_destChain(pointer, bs, r, counters);
            } else if (fieldId == 3) {
                pointer += _read_sender(pointer, bs, r, counters);
            } else if (fieldId == 4) {
                pointer += _read_receiver(pointer, bs, r, counters);
            } else if (fieldId == 5) {
                pointer += _read_amount(pointer, bs, r, counters);
            } else if (fieldId == 6) {
                pointer += _read_token(pointer, bs, r, counters);
            } else if (fieldId == 7) {
                pointer += _read_oriToken(pointer, bs, r, counters);
            } else {
                if (wireType == ProtoBufRuntime.WireType.Fixed64) {
                    uint256 size;
                    (, size) = ProtoBufRuntime._decode_fixed64(pointer, bs);
                    pointer += size;
                }
                if (wireType == ProtoBufRuntime.WireType.Fixed32) {
                    uint256 size;
                    (, size) = ProtoBufRuntime._decode_fixed32(pointer, bs);
                    pointer += size;
                }
                if (wireType == ProtoBufRuntime.WireType.Varint) {
                    uint256 size;
                    (, size) = ProtoBufRuntime._decode_varint(pointer, bs);
                    pointer += size;
                }
                if (wireType == ProtoBufRuntime.WireType.LengthDelim) {
                    uint256 size;
                    (, size) = ProtoBufRuntime._decode_lendelim(pointer, bs);
                    pointer += size;
                }
            }
        }
        return (r, sz);
    }

    // field readers

    /**
     * @dev The decoder for reading a field
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @param r The in-memory struct
     * @param counters The counters for repeated fields
     * @return The number of bytes decoded
     */
    function _read_srcChain(
        uint256 p,
        bytes memory bs,
        Data memory r,
        uint256[8] memory counters
    ) internal pure returns (uint256) {
        /**
         * if `r` is NULL, then only counting the number of fields.
         */
        (string memory x, uint256 sz) = ProtoBufRuntime._decode_string(p, bs);
        if (isNil(r)) {
            counters[1] += 1;
        } else {
            r.srcChain = x;
            if (counters[1] > 0) counters[1] -= 1;
        }
        return sz;
    }

    /**
     * @dev The decoder for reading a field
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @param r The in-memory struct
     * @param counters The counters for repeated fields
     * @return The number of bytes decoded
     */
    function _read_destChain(
        uint256 p,
        bytes memory bs,
        Data memory r,
        uint256[8] memory counters
    ) internal pure returns (uint256) {
        /**
         * if `r` is NULL, then only counting the number of fields.
         */
        (string memory x, uint256 sz) = ProtoBufRuntime._decode_string(p, bs);
        if (isNil(r)) {
            counters[2] += 1;
        } else {
            r.destChain = x;
            if (counters[2] > 0) counters[2] -= 1;
        }
        return sz;
    }

    /**
     * @dev The decoder for reading a field
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @param r The in-memory struct
     * @param counters The counters for repeated fields
     * @return The number of bytes decoded
     */
    function _read_sender(
        uint256 p,
        bytes memory bs,
        Data memory r,
        uint256[8] memory counters
    ) internal pure returns (uint256) {
        /**
         * if `r` is NULL, then only counting the number of fields.
         */
        (string memory x, uint256 sz) = ProtoBufRuntime._decode_string(p, bs);
        if (isNil(r)) {
            counters[3] += 1;
        } else {
            r.sender = x;
            if (counters[3] > 0) counters[3] -= 1;
        }
        return sz;
    }

    /**
     * @dev The decoder for reading a field
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @param r The in-memory struct
     * @param counters The counters for repeated fields
     * @return The number of bytes decoded
     */
    function _read_receiver(
        uint256 p,
        bytes memory bs,
        Data memory r,
        uint256[8] memory counters
    ) internal pure returns (uint256) {
        /**
         * if `r` is NULL, then only counting the number of fields.
         */
        (string memory x, uint256 sz) = ProtoBufRuntime._decode_string(p, bs);
        if (isNil(r)) {
            counters[4] += 1;
        } else {
            r.receiver = x;
            if (counters[4] > 0) counters[4] -= 1;
        }
        return sz;
    }

    /**
     * @dev The decoder for reading a field
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @param r The in-memory struct
     * @param counters The counters for repeated fields
     * @return The number of bytes decoded
     */
    function _read_amount(
        uint256 p,
        bytes memory bs,
        Data memory r,
        uint256[8] memory counters
    ) internal pure returns (uint256) {
        /**
         * if `r` is NULL, then only counting the number of fields.
         */
        (bytes memory x, uint256 sz) = ProtoBufRuntime._decode_bytes(p, bs);
        if (isNil(r)) {
            counters[5] += 1;
        } else {
            r.amount = x;
            if (counters[5] > 0) counters[5] -= 1;
        }
        return sz;
    }

    /**
     * @dev The decoder for reading a field
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @param r The in-memory struct
     * @param counters The counters for repeated fields
     * @return The number of bytes decoded
     */
    function _read_token(
        uint256 p,
        bytes memory bs,
        Data memory r,
        uint256[8] memory counters
    ) internal pure returns (uint256) {
        /**
         * if `r` is NULL, then only counting the number of fields.
         */
        (string memory x, uint256 sz) = ProtoBufRuntime._decode_string(p, bs);
        if (isNil(r)) {
            counters[6] += 1;
        } else {
            r.token = x;
            if (counters[6] > 0) counters[6] -= 1;
        }
        return sz;
    }

    /**
     * @dev The decoder for reading a field
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @param r The in-memory struct
     * @param counters The counters for repeated fields
     * @return The number of bytes decoded
     */
    function _read_oriToken(
        uint256 p,
        bytes memory bs,
        Data memory r,
        uint256[8] memory counters
    ) internal pure returns (uint256) {
        /**
         * if `r` is NULL, then only counting the number of fields.
         */
        (string memory x, uint256 sz) = ProtoBufRuntime._decode_string(p, bs);
        if (isNil(r)) {
            counters[7] += 1;
        } else {
            r.oriToken = x;
            if (counters[7] > 0) counters[7] -= 1;
        }
        return sz;
    }

    // Encoder section

    /**
     * @dev The main encoder for memory
     * @param r The struct to be encoded
     * @return The encoded byte array
     */
    function encode(Data memory r) internal pure returns (bytes memory) {
        bytes memory bs = new bytes(_estimate(r));
        uint256 sz = _encode(r, 32, bs);
        assembly {
            mstore(bs, sz)
        }
        return bs;
    }

    // inner encoder

    /**
     * @dev The encoder for internal usage
     * @param r The struct to be encoded
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @return The number of bytes encoded
     */
    function _encode(
        Data memory r,
        uint256 p,
        bytes memory bs
    ) internal pure returns (uint256) {
        uint256 offset = p;
        uint256 pointer = p;

        if (bytes(r.srcChain).length != 0) {
            pointer += ProtoBufRuntime._encode_key(
                1,
                ProtoBufRuntime.WireType.LengthDelim,
                pointer,
                bs
            );
            pointer += ProtoBufRuntime._encode_string(r.srcChain, pointer, bs);
        }
        if (bytes(r.destChain).length != 0) {
            pointer += ProtoBufRuntime._encode_key(
                2,
                ProtoBufRuntime.WireType.LengthDelim,
                pointer,
                bs
            );
            pointer += ProtoBufRuntime._encode_string(r.destChain, pointer, bs);
        }
        if (bytes(r.sender).length != 0) {
            pointer += ProtoBufRuntime._encode_key(
                3,
                ProtoBufRuntime.WireType.LengthDelim,
                pointer,
                bs
            );
            pointer += ProtoBufRuntime._encode_string(r.sender, pointer, bs);
        }
        if (bytes(r.receiver).length != 0) {
            pointer += ProtoBufRuntime._encode_key(
                4,
                ProtoBufRuntime.WireType.LengthDelim,
                pointer,
                bs
            );
            pointer += ProtoBufRuntime._encode_string(r.receiver, pointer, bs);
        }
        if (r.amount.length != 0) {
            pointer += ProtoBufRuntime._encode_key(
                5,
                ProtoBufRuntime.WireType.LengthDelim,
                pointer,
                bs
            );
            pointer += ProtoBufRuntime._encode_bytes(r.amount, pointer, bs);
        }
        if (bytes(r.token).length != 0) {
            pointer += ProtoBufRuntime._encode_key(
                6,
                ProtoBufRuntime.WireType.LengthDelim,
                pointer,
                bs
            );
            pointer += ProtoBufRuntime._encode_string(r.token, pointer, bs);
        }
        if (bytes(r.oriToken).length != 0) {
            pointer += ProtoBufRuntime._encode_key(
                7,
                ProtoBufRuntime.WireType.LengthDelim,
                pointer,
                bs
            );
            pointer += ProtoBufRuntime._encode_string(r.oriToken, pointer, bs);
        }
        return pointer - offset;
    }

    // nested encoder

    /**
     * @dev The encoder for inner struct
     * @param r The struct to be encoded
     * @param p The offset of bytes array to start decode
     * @param bs The bytes array to be decoded
     * @return The number of bytes encoded
     */
    function _encode_nested(
        Data memory r,
        uint256 p,
        bytes memory bs
    ) internal pure returns (uint256) {
        /**
         * First encoded `r` into a temporary array, and encode the actual size used.
         * Then copy the temporary array into `bs`.
         */
        uint256 offset = p;
        uint256 pointer = p;
        bytes memory tmp = new bytes(_estimate(r));
        uint256 tmpAddr = ProtoBufRuntime.getMemoryAddress(tmp);
        uint256 bsAddr = ProtoBufRuntime.getMemoryAddress(bs);
        uint256 size = _encode(r, 32, tmp);
        pointer += ProtoBufRuntime._encode_varint(size, pointer, bs);
        ProtoBufRuntime.copyBytes(tmpAddr + 32, bsAddr + pointer, size);
        pointer += size;
        delete tmp;
        return pointer - offset;
    }

    // estimator

    /**
     * @dev The estimator for a struct
     * @param r The struct to be encoded
     * @return The number of bytes encoded in estimation
     */
    function _estimate(Data memory r) internal pure returns (uint256) {
        uint256 e;
        e += 1 + ProtoBufRuntime._sz_lendelim(bytes(r.srcChain).length);
        e += 1 + ProtoBufRuntime._sz_lendelim(bytes(r.destChain).length);
        e += 1 + ProtoBufRuntime._sz_lendelim(bytes(r.sender).length);
        e += 1 + ProtoBufRuntime._sz_lendelim(bytes(r.receiver).length);
        e += 1 + ProtoBufRuntime._sz_lendelim(r.amount.length);
        e += 1 + ProtoBufRuntime._sz_lendelim(bytes(r.token).length);
        e += 1 + ProtoBufRuntime._sz_lendelim(bytes(r.oriToken).length);
        return e;
    }

    // empty checker

    function _empty(Data memory r) internal pure returns (bool) {
        if (bytes(r.srcChain).length != 0) {
            return false;
        }

        if (bytes(r.destChain).length != 0) {
            return false;
        }

        if (bytes(r.sender).length != 0) {
            return false;
        }

        if (bytes(r.receiver).length != 0) {
            return false;
        }

        if (r.amount.length != 0) {
            return false;
        }

        if (bytes(r.token).length != 0) {
            return false;
        }

        if (bytes(r.oriToken).length != 0) {
            return false;
        }

        return true;
    }

    //store function
    /**
     * @dev Store in-memory struct to storage
     * @param input The in-memory struct
     * @param output The in-storage struct
     */
    function store(Data memory input, Data storage output) internal {
        output.srcChain = input.srcChain;
        output.destChain = input.destChain;
        output.sender = input.sender;
        output.receiver = input.receiver;
        output.amount = input.amount;
        output.token = input.token;
        output.oriToken = input.oriToken;
    }

    //utility functions
    /**
     * @dev Return an empty struct
     * @return r The empty struct
     */
    function nil() internal pure returns (Data memory r) {
        assembly {
            r := 0
        }
    }

    /**
     * @dev Test whether a struct is empty
     * @param x The struct to be tested
     * @return r True if it is empty
     */
    function isNil(Data memory x) internal pure returns (bool r) {
        assembly {
            r := iszero(x)
        }
    }
}
//library TokenTransfer
