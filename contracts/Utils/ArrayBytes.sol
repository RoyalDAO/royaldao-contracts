// SPDX-License-Identifier: MIT
/*
 * @title Solidity Bytes Uint Array Management
 *
 * @dev Utility library to manage uint arrays (16, 32, 64, 128 and 256) for ethereum contracts written in Solidity.
 *      The library lets you concatenate, slice and type cast bytes arrays both in memory and storage.
 */
pragma solidity >=0.8.0 <0.9.0;

import "solidity-bytes-utils/contracts/BytesLib.sol";

library BytesArrayLib {
    using BytesLib for bytes;

    function insertStorage(bytes storage _self, bytes memory _value) internal {
        _self.concatStorage(_value);
    }

    function insert(bytes memory _self, bytes memory _value)
        internal
        pure
        returns (bytes memory)
    {
        return _self.concat(_value);
    }

    function length(bytes storage _self) internal view returns (uint256) {
        return _self.length - 1;
    }

    function getUint16(bytes memory _self, uint256 _start)
        internal
        pure
        returns (uint16)
    {
        return _self.toUint16(_start);
    }

    function getUint32(bytes memory _self, uint256 _start)
        internal
        pure
        returns (uint32)
    {
        return _self.toUint32(_start);
    }

    function getArrayUint32(bytes memory _self)
        internal
        pure
        returns (uint32[] memory _array)
    {
        _array = new uint32[](_self.length / 0x04);

        for (uint256 idx = 0; idx < _array.length; idx++) {
            _array[idx] = _self.toUint32(0x04 * idx);
        }
        return _array;
    }

    function _getArrayUint32(uint32[] memory to, bytes memory from)
        internal
        pure
    {
        to = new uint32[](from.length / 4);
        uint32 tempValue;
        // Compute the base location of array's data by taking SHA3 of its position (slot)
        uint256 addr;
        bytes32 base;
        assembly {
            // load array to write on it
            mstore(addr, to)
            base := keccak256(addr, 32)
            // Store the length of the first bytes array at the beginning of
            // the memory for tempBytes.
            let lengthFrom := mload(from)
            //mstore(tempBytes, lengthFrom)
            // Maintain a memory counter for the current write location in the
            // temp bytes array by adding the 32 bytes for the array length to
            // the starting location.
            let mc := add(from, 0x20)
            // Stop copying when the memory counter reaches the length of the
            // first bytes array.
            let end := add(mc, lengthFrom)

            for {
                // Initialize a copy counter to the start of the _preBytes data,
                // 32 bytes into its memory.
                let cc := add(from, 0x20)
            } lt(mc, end) {
                // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                //read value from position and push to array
                tempValue := mload(cc)
                //write value to array position
                mstore(add(base, 32), tempValue)
            }
        }
    }

    function getUint64(bytes memory _self, uint256 _start)
        internal
        pure
        returns (uint64)
    {
        return _self.toUint64(_start);
    }

    function getUint128(bytes memory _self, uint256 _start)
        internal
        pure
        returns (uint128)
    {
        return _self.toUint128(_start);
    }

    function getUint256(bytes memory _self, uint256 _start)
        internal
        pure
        returns (uint256)
    {
        return _self.toUint256(_start);
    }

    function equal(bytes memory _preBytes, bytes memory _postBytes)
        internal
        pure
        returns (bool)
    {
        return _preBytes.equal(_postBytes);
    }

    function equalStorage(bytes storage _preBytes, bytes memory _postBytes)
        internal
        view
        returns (bool)
    {
        return _preBytes.equalStorage(_postBytes);
    }
}
