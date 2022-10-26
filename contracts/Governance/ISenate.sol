// SPDX-License-Identifier: MIT
// RoyalDAO Contracts (last updated v1.0.0) (Governance/Senate.sol)
// Uses OpenZeppelin Contracts and Libraries

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Interface of the {Senate} core.
 *
 * _Available since v1.0._
 * ISenate.sol is based on some functions from OpenZeppelin's IGovernor.sol and expands it for a more complex DAO access control:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/IGovernor.sol
 * IGovernor.sol source code copyright OpenZeppelin licensed under the MIT License.
 * Modified by RoyalDAO.
 */
abstract contract ISenate is IERC165 {
    enum membershipStatus {
        NOT_MEMBER,
        ACTIVE_MEMBER,
        QUARANTINE_MEMBER,
        BANNED_MEMBER
    }

    enum senateSenatorStatus {
        NOT_SENATOR,
        ACTIVE_SENATOR,
        QUARANTINE_SENATOR,
        BANNED_SENATOR
    }

    /**
     * @notice module:core
     * @dev Open Senate with initial Members. Initial Members don't need to pass through Senate approval process. They are the founders members.
     */
    function openSenate(address[] memory _tokens) external virtual;

    /**
     * @dev Update Senate Voting Books.
     */
    function transferVotingUnits(
        address from,
        address to,
        uint256 amount,
        bool isSenator,
        bool updateTotalSupply
    ) external virtual;

    /**
     * @dev Check if all members from list are valid.
     */
    function validateMembers(bytes calldata members)
        external
        view
        virtual
        returns (bool);

    /**
     * @dev Check if senator is active and able to participate in the Senate.
     */
    function validateSenator(address senator)
        external
        view
        virtual
        returns (bool);

    /**
     * @dev Get the current senator representation list in bytes.
     */
    function getRepresentation(address account)
        external
        view
        virtual
        returns (bytes memory);

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
     * @dev get senate member status
     */
    function senateMemberStatus(address _tokenAddress)
        public
        view
        virtual
        returns (membershipStatus);

    /**
     * @dev get senator status
     */
    function senatorStatus(address _senator)
        public
        view
        virtual
        returns (senateSenatorStatus);

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
}
