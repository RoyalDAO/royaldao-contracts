// SPDX-License-Identifier: MIT
// RoyalDAO Contracts (last updated v1.0.0) (Governance/extensions/ChancellorCountingSimple.sol)
// Uses OpenZeppelin Contracts and Libraries

pragma solidity ^0.8.0;

import "../Chancellor.sol";

/**
 * @dev Extension of {Chancellor} for simple, 3 options, vote counting.
 *
 * ChancellorCountingSimple.sol modifies OpenZeppelin's GovernorCountingSimple.sol:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/extensions/GovernorCountingSimple.sol
 * GovernorCountingSimple.sol source code copyright OpenZeppelin licensed under the MIT License.
 * Modified by RoyalDAO.
 *
 * CHANGES: Adapted to work with the Senate
 *
 * _Available since v1.0._
 */
abstract contract ChancellorCountingSimple is Chancellor {
    /**
     * @dev Supported vote types. Matches Governor Bravo ordering.
     */
    enum VoteType {
        Against,
        For,
        Abstain
    }

    struct ProposalVote {
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => ProposalVote) private _proposalVotes;

    /**
     * @dev See {IChancellor-COUNTING_MODE}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE()
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @dev See {IChancellor-hasVoted}.
     */
    function hasVoted(uint256 proposalId, address account)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @dev Accessor to the internal vote counts.
     */
    function proposalVotes(uint256 proposalId)
        public
        view
        virtual
        returns (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        )
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (
            proposalVote.againstVotes,
            proposalVote.forVotes,
            proposalVote.abstainVotes
        );
    }

    /**
     * @dev See {Chancellor-_countVote}. In this module, the support follows the `VoteType` enum (from Governor Bravo).
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory // params
    ) internal virtual override {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        require(
            !proposalVote.hasVoted[account],
            "ChancellorVotingSimple: vote already cast"
        );
        proposalVote.hasVoted[account] = true;

        if (support == uint8(VoteType.Against)) {
            proposalVote.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposalVote.forVotes += weight;
        } else if (support == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += weight;
        } else {
            revert("ChancellorVotingSimple: invalid value for enum VoteType");
        }
    }

    /**
     * @dev See {Chancellor-_quorumReached}.
     */
    function _quorumReached(uint256 proposalId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return
            quorum(proposalSnapshot(proposalId)) <=
            proposalVote.forVotes + proposalVote.abstainVotes;
    }

    /**
     * @dev See {Chancellor-_voteSucceeded}. In this module, the forVotes must be strictly over the againstVotes.
     */
    function _voteSucceeded(uint256 proposalId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return proposalVote.forVotes > proposalVote.againstVotes;
    }
}
