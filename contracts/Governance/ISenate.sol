// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (governance/IGovernor.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Interface of the {Senate} core.
 *
 * _Available since v4.3._
 * IChancelorUpgradeable.sol modifies OpenZeppelin's IGovernorUpgradeable.sol:
 * https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/governance/IGovernorUpgradeable.sol
 * IGovernorUpgradeable.sol source code copyright OpenZeppelin licensed under the MIT License.
 * Modified by QueenE DAO.
 */
abstract contract ISenate is IERC165 {
    event NewDeputyInTown(address newDeputy, uint256 mandateEndsAtBlock);
    event DeputyResignation(address deputy, uint256 resignedAt);

    event MemberQuarantined(address member);
    event SenatorQuarantined(address senator);

    event MemberBanned(address member);
    event SenatorBanned(address senator);

    enum membershipStatus {
        NOT_MEMBER,
        ACTIVE_MEMBER,
        QUARANTINE_MEMBER,
        BANNED_MEMBER
    }

    /**
     * @notice module:core
     * @dev Name of the senate instance (used in building the ERC712 domain separator).
     */
    function name() public view virtual returns (string memory);

    /**
     * @notice module:core
     * @dev Version of the senate instance (used in building the ERC712 domain separator). Default: "1"
     */
    function version() public view virtual returns (string memory);

    /**
     * @notice module:user-config
     * @dev Delay, in number of block, between the proposal is created and the vote starts. This can be increassed to
     * leave time for users to buy voting power, or delegate it, before the voting of a proposal starts.
     */
    function votingDelay() public view virtual returns (uint256);

    /**
     * @notice module:user-config
     * @dev Delay, in number of blocks, between the vote start and vote ends.
     *
     * NOTE: The {votingDelay} can delay the start of the vote. This must be considered when setting the voting
     * duration compared to the voting delay.
     */
    function votingPeriod() public view virtual returns (uint256);

    /**
     * @notice module:user-config
     * @dev Minimum number of cast voted required for a proposal to be successful.
     *
     * Note: The `blockNumber` parameter corresponds to the snapshot used for counting vote. This allows to scale the
     * quorum depending on values such as the totalSupply of a token at this block (see {ERC20Votes}).
     */
    function quorum(uint256 blockNumber) public view virtual returns (uint256);

    function changeDeputyMarshal(address _newMarshalInTown) external virtual;

    /**
     * @dev Update Senate Voting Books.
     */
    function transferVotingUnits(
        address from,
        address to,
        uint256 amount,
        bool isSenator
    ) external virtual;

    /**
     * @dev Check if all members from list are valid.
     */
    function validateMembers(address[] calldata members)
        external
        view
        virtual
        returns (bool);

    /**
     * @dev Check if senator is active.
     */
    function validateSenator(address senator)
        public
        view
        virtual
        returns (bool);
}
