// SPDX-License-Identifier: MIT
// RoyalDAO Contracts (last updated v1.0.0) (Governance/IChancellorTimelock.sol)
// Uses OpenZeppelin Contracts and Libraries

pragma solidity ^0.8.0;

import "../IChancellor.sol";

/**
 * @dev Extension of the {IChancellor} for timelock supporting modules.
 *
 * _Available since v4.3._
 */
abstract contract IChancellorTimelock is IChancellor {
    event ProposalQueued(uint256 proposalId, uint256 eta);

    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256 proposalId);

    function timelock() public view virtual returns (address);

    function proposalEta(uint256 proposalId)
        public
        view
        virtual
        returns (uint256);
}
