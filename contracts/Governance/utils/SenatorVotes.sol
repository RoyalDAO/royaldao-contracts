// SPDX-License-Identifier: MIT
// RoyalDAO Contracts (last updated v1.1.2) (Governance/utils/SenatorVotes.sol)
// Uses OpenZeppelin Contracts and Libraries

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./ISenatorVotes.sol";
import "../../Governance/ISenate.sol";
import "../../Utils/Checkpoints.sol";

/**
 * @dev Extension of ERC721 to support voting and delegation as implemented by {SenatorVotes}, where each individual NFT counts
 * as 1 vote unit.
 *
 * Tokens do not count as votes until they are delegated, because votes must be tracked which incurs an additional cost
 * on every transfer. Token holders can either delegate to a trusted representative who will decide how to make use of
 * the votes in governance decisions, or they can delegate to themselves to be their own representative.
 *
 * SenatorVotes.sol modifies OpenZeppelin's Votes.sol:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/utils/Votes.sol
 * Votes.sol source code copyright OpenZeppelin licensed under the MIT License.
 * Modified by RoyalDAO.
 *
 * CHANGES: - Adapted to work with the {Senate}, sending an aditional move of delegated vote to the {Senate} that the token is part of (if any)
 *          - Keeps a list of current senators (holders) to allow a full snapshot in the case of a late {Senate} Participation
            - Allow the setup of senate and posible change of senate (senate leave and senate change scenarios)
 *
 * _Available since v1.0._
 */

abstract contract SenatorVotes is ISenatorVotes, Context, EIP712 {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    constructor(ISenate _senate) {
        _setSenate(_senate);
    }

    using Checkpoints for Checkpoints.History;
    using Counters for Counters.Counter;

    ISenate public senate;

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => address) private _delegation;
    mapping(address => Checkpoints.History) private _delegateCheckpoints;
    Checkpoints.History private _totalCheckpoints;

    mapping(address => Counters.Counter) private _nonces;

    EnumerableSet.AddressSet internal senators;

    /**
     * @dev Returns the current amount of votes that `account` has.
     */
    function getVotes(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _delegateCheckpoints[account].latest();
    }

    /**
     * @dev Returns the amount of votes that `account` had at the end of a past block (`blockNumber`).
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastVotes(address account, uint256 blockNumber)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return
            _delegateCheckpoints[account].getAtProbablyRecentBlock(blockNumber);
    }

    /**
     * @dev Returns the total supply of votes available at the end of a past block (`blockNumber`).
     *
     * NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
     * Votes that have not been delegated are still part of total supply, even though they would not participate in a
     * vote.
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastTotalSupply(uint256 blockNumber)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(blockNumber < block.number, "Votes: block not yet mined");
        return _totalCheckpoints.getAtProbablyRecentBlock(blockNumber);
    }

    /**
     * @dev Returns the current total supply of votes.
     */
    function _getTotalSupply() internal view virtual returns (uint256) {
        return _totalCheckpoints.latest();
    }

    /**
     * @dev Returns the delegate that `account` has chosen.
     */
    function delegates(address account)
        public
        view
        virtual
        override
        returns (address)
    {
        return _delegation[account];
    }

    /**
     * @dev Delegates votes from the sender to `delegatee`.
     */
    function delegate(address delegatee) public virtual override {
        address account = _msgSender();
        _delegate(account, delegatee);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`.
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        require(block.timestamp <= expiry, "Votes: signature expired");
        address signer = ECDSA.recover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry)
                )
            ),
            v,
            r,
            s
        );
        require(nonce == _useNonce(signer), "Votes: invalid nonce");
        _delegate(signer, delegatee);
    }

    /**
     * @dev Delegate all of `account`'s voting units to `delegatee`.
     *
     * Emits events {DelegateChanged} and {DelegateVotesChanged}.
     */
    function _delegate(address account, address delegatee) internal virtual {
        address oldDelegate = delegates(account);
        _delegation[account] = delegatee;

        emit DelegateChanged(account, oldDelegate, delegatee);

        bool fromStillSenator = _moveDelegateVotes(
            oldDelegate,
            delegatee,
            _getVotingUnits(account)
        );

        //update senate books
        if (address(senate) != address(0))
            senate.transferVotingUnits(
                oldDelegate,
                delegatee,
                _getVotingUnits(account),
                fromStillSenator,
                false
            );
    }

    /**
     * @dev Transfers, mints, or burns voting units. To register a mint, `from` should be zero. To register a burn, `to`
     * should be zero. Total supply of voting units will be adjusted with mints and burns.
     *
     * NOTE If tokens participates in a Senate, an external call to the Senate contract is made to update the Senate Books updated.
     */
    function _transferVotingUnits(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (from == address(0)) {
            _totalCheckpoints.push(_add, amount);
        }
        if (to == address(0)) {
            _totalCheckpoints.push(_subtract, amount);
        }

        bool fromStillSenator = _moveDelegateVotes(
            delegates(from),
            delegates(to),
            amount
        );

        //update senate books
        if (address(senate) != address(0))
            senate.transferVotingUnits(
                from,
                to,
                amount,
                fromStillSenator,
                true
            );
    }

    /**
     * @dev Moves delegated votes from one delegate to another.
     *
     * NOTE if `from` keeps no voting power and is in Senator list, removes it
     *      `to` is inserted as senator if its not already
     */
    function _moveDelegateVotes(
        address from,
        address to,
        uint256 amount
    ) private returns (bool fromStillSenator) {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _delegateCheckpoints[
                    from
                ].push(_subtract, amount);

                fromStillSenator = newValue > 0;
                if (senators.contains(from) && newValue <= 0)
                    senators.remove(from);

                emit DelegateVotesChanged(from, oldValue, newValue);
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _delegateCheckpoints[to]
                    .push(_add, amount);

                if (!senators.contains(to) && newValue > 0) senators.add(to);

                emit DelegateVotesChanged(to, oldValue, newValue);
            }
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner)
        internal
        virtual
        returns (uint256 current)
    {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    /**
     * @dev Returns an address nonce.
     */
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev Returns the contract's {EIP712} domain separator.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Must return the voting units held by an account.
     */
    function _getVotingUnits(address) internal view virtual returns (uint256);

    /**
     * @dev Returns the senate address known by token.
     */
    function getSenateAddress() external view returns (address) {
        return address(senate);
    }

    /**
     * @dev Returns snapshot of senator votes
     */
    function getSenateSnapshot()
        external
        view
        returns (senateSnapshot[] memory)
    {
        senateSnapshot[] memory snapshot = new senateSnapshot[](
            senators.length()
        );

        for (uint256 idx = 0; idx < senators.length(); idx++) {
            snapshot[idx] = senateSnapshot({
                senator: senators.at(idx),
                votes: _delegateCheckpoints[senators.at(idx)].latest()
            });
        }

        return snapshot;
    }

    /**
     * @dev Returns current voting suply
     */
    function getTotalSupply() external view override returns (uint256) {
        return _getTotalSupply();
    }

    /**
     * @dev Set senate address.
     */
    function setSenate(ISenate _senate) external virtual {
        _setSenate(_senate);
    }

    /**
     * @dev Set senate address.
     *
     * NOTE If member wants to change to another senate or even to no senate at all, first it must be deactivated from current senate
     *
     */
    function _setSenate(ISenate _senate) internal virtual {
        if (address(senate) != address(0))
            require(
                uint256(senate.senateMemberStatus(address(_senate))) !=
                    uint256(membershipStatus.ACTIVE_MEMBER),
                "SenatorVotes::Current active in Senate"
            );

        address oldSenate = address(senate);

        senate = _senate;

        emit SenateChanged(oldSenate, address(senate));
    }
}
