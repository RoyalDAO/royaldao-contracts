// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorTimelockControl.sol)

pragma solidity ^0.8.0;

import "./IChancellorSenate.sol";
import "../Chancellor.sol";
import "../Senate.sol";

/**
 * @dev Extension of {Chancellor} that binds the execution process to an instance of {TimelockController}. This adds a
 * delay, enforced by the {TimelockController} to all successful proposal (in addition to the voting duration). The
 * {Chancellor} needs the proposer (and ideally the executor) roles for the {Chancellor} to work properly.
 *
 * Using this model means the proposal will be operated by the {TimelockController} and not by the {Chancellor}. Thus,
 * the assets and permissions must be attached to the {TimelockController}. Any asset sent to the {Chancellor} will be
 * inaccessible.
 *
 * WARNING: Setting up the TimelockController to have additional proposers besides the Chancellor is very risky, as it
 * grants them powers that they must be trusted or known not to use: 1) {onlyChancellor} functions like {relay} are
 * available to them through the timelock, and 2) approved Chancellor proposals can be blocked by them, effectively
 * executing a Denial of Service attack. This risk will be mitigated in a future release.
 *
 * _Available since v4.3._
 */
abstract contract ChancellorSenateControl is IChancellorSenate, Chancellor {
    Senate private _senate;

    /**
     * @dev Set the timelock.
     */
    constructor(Senate senateAddress) {
        _updateSenate(senateAddress);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, Chancellor)
        returns (bool)
    {
        return
            interfaceId == type(IChancellorSenate).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Public accessor to check the address of the timelock
     */
    function senate() public view virtual override returns (address) {
        return address(_senate);
    }

    /**
     * @dev Public endpoint to update the underlying timelock instance. Restricted to the timelock itself, so updates
     * must be proposed, scheduled, and executed through Chancellor proposals.
     *
     * CAUTION: It is not recommended to change the timelock while there are other queued Chancellor proposals.
     */
    function updateSenate(Senate newSenate) external virtual onlyChancellor {
        _updateSenate(newSenate);
    }

    function _updateSenate(Senate newSenate) private {
        emit SenateChange(address(_senate), address(newSenate));
        _senate = newSenate;
    }

    function votingDelay() public view virtual override returns (uint256) {
        return _senate.votingDelay();
    }

    function votingPeriod() public view virtual override returns (uint256) {
        return _senate.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _senate.quorum(blockNumber);
    }

    function proposalThreshold()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _senate.proposalThreshold();
    }

    function getSettings()
        public
        view
        virtual
        override
        returns (
            uint256 currProposalThreshold,
            uint256 currVotingDelay,
            uint256 currVotingPeriod,
            bytes memory senatorRepresentations,
            uint256 votingPower,
            bool validSenator,
            bool validMembers
        )
    {
        return _senate.getSettings(msg.sender);
    }

    /**
     * Read the voting weight from the token's built in snapshot mechanism (see {Governor-_getVotes}).
     */
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory /*params*/
    ) internal view virtual override returns (uint256) {
        return _senate.getVotes(account, blockNumber, _defaultParams());
    }

    /**
     * Validate a list of Members
     */
    function _validateMembers(bytes memory members)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return _senate.validateMembers(members);
    }

    /**
     * Validate Senator
     */
    function _validateSenator(address senator)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return _senate.validateSenator(senator);
    }
}
