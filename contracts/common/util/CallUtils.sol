// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

library CallUtils {

    /// @dev Bubble up the revert from the returnedData (supports Panic, Error & Custom Errors)
    /// @notice This is needed in order to provide some human-readable revert message from a call
    /// @param _resultData Response of the call
    function getRevertMsg(bytes memory _resultData) internal pure returns (string memory reason) {
        if (_resultData.length < 4) {
            // Case 1: catch all
            return "CallUtils: target revert()";
        } else {
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(_resultData, 0x20))
            }
            if (errorSelector == bytes4(0x4e487b71) /* `seth sig "Panic(uint256)"` */) {
                // Case 2: Panic(uint256) (Defined since 0.8.0)
                // solhint-disable-next-line max-line-length
                // ref: https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require)
                reason = "CallUtils: target panicked: 0x__";
                uint errorCode;
                assembly {
                    errorCode := mload(add(_resultData, 0x24))
                    let reasonWord := mload(add(reason, 0x20))
                    // [0..9] is converted to ['0'..'9']
                    // [0xa..0xf] is not correctly converted to ['a'..'f']
                    // but since panic code doesn't have those cases, we will ignore them for now!
                    let e1 := add(and(errorCode, 0xf), 0x30)
                    let e2 := shl(8, add(shr(4, and(errorCode, 0xf0)), 0x30))
                    reasonWord := or(
                        and(reasonWord, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000),
                        or(e2, e1))
                    mstore(add(reason, 0x20), reasonWord)
                }
                return reason;
            } 
            else {
                // Case 3: Error(string) (Defined at least since 0.7.0)
                // Case 4: Custom errors (Defined since 0.8.0)
                
                // If the _resultData length is less than 68, then the transaction failed silently (without a revert message)
                if (_resultData.length < 68) return 'CallUtils: Transaction reverted silently';

                // Remove the selector which is the first 4 bytes
                // bytes memory revertData = _resultData.slice(4, _resultData.length - 4); 
                // return abi.decode(revertData, (string)); 

                uint len = _resultData.length;
                uint t;
                assembly {
                    _resultData := add (_resultData, 4)
                    t := mload (_resultData) // Save the content of the length slot
                    mstore (_resultData, sub (len, 4)) // Set proper length
                }
                reason = abi.decode (_resultData, (string));
                assembly {
                    mstore (_resultData, t) // Restore the content of the length slot
                }
                return reason;
            }
        }
    }

    /**
    * @dev Helper method to parse data and extract the method signature (selector).
    *
    * Copied from: https://github.com/argentlabs/argent-contracts/
    * blob/master/contracts/modules/common/Utils.sol#L54-L60
    */
    function parseSelector(bytes memory callData) internal pure returns (bytes4 selector) {
        require(callData.length >= 4, "CallUtils: invalid callData");
        // solhint-disable-next-line no-inline-assembly
        assembly {
            selector := mload(add(callData, 0x20))
        }
    }

    /**
     * @dev Pad length to 32 bytes word boundary
     */
    function padLength32(uint256 len) internal pure returns (uint256 paddedLen) {
        return ((len / 32) +  (((len & 31) > 0) /* rounding? */ ? 1 : 0)) * 32;
    }

    /**
     * @dev Validate if the data is encoded correctly with abi.encode(bytesData)
     *
     * Expected ABI Encode Layout:
     * | word 1      | word 2           | word 3           | the rest...
     * | data length | bytesData offset | bytesData length | bytesData + padLength32 zeros |
     */
    function isValidAbiEncodedBytes(bytes memory data) internal pure returns (bool) {
        if (data.length < 64) return false;
        uint bytesOffset;
        uint bytesLen;
        // bytes offset is always expected to be 32
        assembly { bytesOffset := mload(add(data, 32)) }
        if (bytesOffset != 32) return false;
        assembly { bytesLen := mload(add(data, 64)) }
        // the data length should be bytesData.length + 64 + padded bytes length
        return data.length == 64 + padLength32(bytesLen);
    }

}