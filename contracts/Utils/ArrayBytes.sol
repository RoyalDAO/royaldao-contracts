// SPDX-License-Identifier: MIT
/*
 * @title Solidity Bytes Uint Array Management
 *
 * @dev Utility library to manage uint arrays (16, 32, 64, 128 and 256) for ethereum contracts written in Solidity.
 *      The library lets you concatenate, slice and type cast bytes arrays both in memory and storage.
 */
pragma solidity >=0.8.0 <0.9.0;

import "solidity-bytes-utils/contracts/BytesLib.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

library BytesArrayLib32 {
    using BytesLib for bytes;
    using Strings for uint32;

    function insert(bytes memory _self, uint32 _value)
        internal
        pure
        returns (bytes memory result)
    {
        if (!contains(_self, _value))
            return _self.concat(abi.encodePacked(_value));
    }

    function insertStorage(bytes storage _self, uint32 _value) internal {
        if (!contains(_self, _value))
            _self.concatStorage(abi.encodePacked(_value));
    }

    function remove(bytes memory _self, uint32 _value)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory newBytes;

        for (uint256 idx = 0; idx < (_self.length / 0x04); idx++) {
            uint32 storedValue = _self.toUint32(0x04 * idx);
            if (storedValue != _value) newBytes = insert(newBytes, storedValue);
        }
        return newBytes;
    }

    function contains(bytes memory _self, uint32 _value)
        internal
        pure
        returns (bool)
    {
        for (uint256 idx = 0; idx < (_self.length / 0x04); idx++) {
            uint32 storedValue = _self.toUint32(0x04 * idx);
            if (storedValue == _value) return true;
        }
        return false;
    }

    function count(bytes memory _self) internal pure returns (uint256) {
        return (_self.length / 0x04);
    }

    function getValue(bytes memory _self, uint256 _index)
        internal
        pure
        returns (uint32)
    {
        //return _self.toUint32(_index);
        return _self.toUint32(0x04 * _index);
    }

    function getArrayStorage(bytes storage _self)
        internal
        view
        returns (uint32[] memory _array)
    {
        _array = new uint32[](_self.length / 0x04);
        //_array[0] = _self.toUint32(0);
        for (uint256 idx = 0; idx < _array.length; idx++) {
            _array[idx] = _self.toUint32(0x04 * idx);
        }

        return _array;
    }

    function getArray(bytes memory _self)
        internal
        pure
        returns (uint32[] memory _array)
    {
        _array = new uint32[](_self.length / 0x04);
        //_array[0] = _self.toUint32(0);
        for (uint256 idx = 0; idx < _array.length; idx++) {
            _array[idx] = _self.toUint32(0x04 * idx);
        }

        return _array;
    }
}
