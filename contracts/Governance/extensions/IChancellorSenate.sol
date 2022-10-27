// SPDX-License-Identifier: MIT
// RoyalDAO Contracts (last updated v1.0.0) (Governance/extensions/IChancellorSenate.sol)

pragma solidity ^0.8.0;

import "../IChancellor.sol";

/**
 * @dev Extension of the {IChancellor} for senate supporting modules.
 *
 * _Available since v1.0._
 */
abstract contract IChancellorSenate is IChancellor {
    /**
     * @dev Emitted when the senate controller used for members control is modified.
     */
    event SenateChange(address oldSenate, address newSenate);

    function senate() public view virtual returns (address);
}
