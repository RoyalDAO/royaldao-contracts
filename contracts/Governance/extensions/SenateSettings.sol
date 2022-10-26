// SPDX-License-Identifier: MIT
// RoyalDAO Contracts (last updated v1.0.0) (Governance/extensions/SenateSettings.sol)
// Uses OpenZeppelin Contracts and Libraries

pragma solidity ^0.8.0;

import "../Senate.sol";

/**
 * @dev Extension of {Senate} for settings updatable through governance.
 *
 * _Available since v1.0.0
 */
abstract contract SenateSettings is Senate {
    uint256 private _votingDelay;
    uint256 private _votingPeriod;
    uint256 private _proposalThreshold;

    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(
        uint256 oldProposalThreshold,
        uint256 newProposalThreshold
    );

    /**
     * @dev Initialize the governance parameters.
     */
    constructor(
        uint256 initialVotingDelay,
        uint256 initialVotingPeriod,
        uint256 initialProposalThreshold
    ) {
        _setVotingDelay(initialVotingDelay);
        _setVotingPeriod(initialVotingPeriod);
        _setProposalThreshold(initialProposalThreshold);
    }

    /**
     * @dev See {Senate-getSettings}.
     */
    function getSettings(address account)
        external
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
        bytes memory representations = _getRepresentation(account);
        return (
            _proposalThreshold,
            _votingDelay,
            _votingPeriod,
            representations,
            _getVotes(account, block.number - 1, ""),
            _validateSenator(account),
            _validateMembers(representations)
        );
    }

    /**
     * @dev Update the voting delay. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingDelaySet} event.
     */
    function setVotingDelay(uint256 newVotingDelay)
        public
        virtual
        onlyChancellor
    {
        _setVotingDelay(newVotingDelay);
    }

    /**
     * @dev Update the voting period. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function setVotingPeriod(uint256 newVotingPeriod)
        public
        virtual
        onlyChancellor
    {
        _setVotingPeriod(newVotingPeriod);
    }

    /**
     * @dev Update the proposal threshold. This operation can only be performed through a Chancellor proposal.
     *
     * Emits a {ProposalThresholdSet} event.
     */
    function setProposalThreshold(uint256 newProposalThreshold)
        public
        virtual
        onlyChancellor
    {
        _setProposalThreshold(newProposalThreshold);
    }

    /**
     * @dev See {ISenate-votingDelay}.
     */
    function votingDelay() public view virtual override returns (uint256) {
        return _votingDelay;
    }

    /**
     * @dev See {ISenate-votingPeriod}.
     */
    function votingPeriod() public view virtual override returns (uint256) {
        return _votingPeriod;
    }

    /**
     * @dev See {Senate-proposalThreshold}.
     */
    function proposalThreshold()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _proposalThreshold;
    }

    /**
     * @dev Internal setter for the voting delay.
     *
     * Emits a {VotingDelaySet} event.
     */
    function _setVotingDelay(uint256 newVotingDelay) internal virtual {
        emit VotingDelaySet(_votingDelay, newVotingDelay);
        _votingDelay = newVotingDelay;
    }

    /**
     * @dev Internal setter for the voting period.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function _setVotingPeriod(uint256 newVotingPeriod) internal virtual {
        // voting period must be at least one block long
        require(
            newVotingPeriod > 0,
            "ChancellorSettings: voting period too low"
        );
        emit VotingPeriodSet(_votingPeriod, newVotingPeriod);
        _votingPeriod = newVotingPeriod;
    }

    /**
     * @dev Internal setter for the proposal threshold.
     *
     * Emits a {ProposalThresholdSet} event.
     */
    function _setProposalThreshold(uint256 newProposalThreshold)
        internal
        virtual
    {
        emit ProposalThresholdSet(_proposalThreshold, newProposalThreshold);
        _proposalThreshold = newProposalThreshold;
    }
}
