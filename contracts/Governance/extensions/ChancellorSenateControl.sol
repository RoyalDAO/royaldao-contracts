// SPDX-License-Identifier: MIT
// RoyalDAO Contracts (last updated v1.0.0) (Governance/extensions/ChancellorSenateControl.sol)

pragma solidity ^0.8.0;

import "./IChancellorSenate.sol";
import "../Chancellor.sol";
import "../Senate.sol";

/**
 * @dev Extension of {Chancellor} that binds the DAO to an instance of {Senate}. This adds a
 * new layer that controls the Members (tokens) that can participate in the DAO.
 *
 * _Available since v1.0._
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
     * @dev Public endpoint to update the underlying senate instance. Restricted to the DAO itself, so updates
     * must be proposed, scheduled (if using a timelock control), and executed through Chancellor proposals.
     *
     * CAUTION: It is not recommended to change the senate while there are active proposals.
     */
    function updateSenate(Senate newSenate) external virtual onlyChancellor {
        _updateSenate(newSenate);
    }

    /**
     * @dev Public accessor to check the address of the senate
     */
    function senate() public view virtual override returns (address) {
        return address(_senate);
    }

    /**
     * @dev Public endpoint to retrieve voting delay from senate
     */
    function votingDelay() public view virtual override returns (uint256) {
        return _senate.votingDelay();
    }

    /**
     * @dev Public endpoint to retrieve voting period from senate
     */
    function votingPeriod() public view virtual override returns (uint256) {
        return _senate.votingPeriod();
    }

    /**
     * @dev Public endpoint to retrieve quorum at given block from senate
     */
    function quorum(uint256 blockNumber)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _senate.quorum(blockNumber);
    }

    /**
     * @dev Public endpoint to retrieve proposal Threshold from senate
     */
    function proposalThreshold()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _senate.proposalThreshold();
    }

    /**
     * @dev Public endpoint to retrieve all configurations from senate in one single external call
     *
     * NOTE The function always checks the status of Senator and his Representation Members
     */
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
     * Read the voting weight from the senates's built in snapshot mechanism (see {Chancelor-_getVotes}).
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

    /**
     * @dev Private endpoint to update the underlying senate instance.
     * @dev Emits SenateChange event
     *
     * CAUTION: It is not recommended to change the senate while there are active proposals.
     */
    function _updateSenate(Senate newSenate) private {
        emit SenateChange(address(_senate), address(newSenate));
        _senate = newSenate;
    }
}
