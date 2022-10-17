// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (governance/extensions/IGovernorTimelock.sol)

pragma solidity ^0.8.0;

import "../IChancellor.sol";

/**
 * @dev Extension of the {IChancellor} for timelock supporting modules.
 *
 * _Available since v4.3._
 */
abstract contract IChancellorSenate is IChancellor {
    /**
     * @dev Emitted when the senate controller used for members control is modified.
     */
    event SenateChange(address oldSenate, address newSenate);

    function senate() public view virtual returns (address);
}