// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.0;

import "../Senate.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../../Utils/Checkpoints.sol";

/**
 * @dev Extension of {Senate} for voting weight extraction from an {ERC721Votes} token.
 *
 */
abstract contract SenateVotes is Senate {
    //TODO: Complex votes for single vote by token
    using EnumerableSet for EnumerableSet.AddressSet;

    using Checkpoints for Checkpoints.History;
    using Counters for Counters.Counter;

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => Checkpoints.History) internal _senateBooksCheckpoints;
    Checkpoints.History internal _totalSenateBooksCheckpoints;
    //checkpoints by senator
    //mapping(address => mapping(address => Checkpoints.History))
    //    internal _senateBooksByMemberCheckpoints;
    //senator representations
    mapping(address => EnumerableSet.AddressSet)
        internal _senatorRepresentations;

    mapping(address => Counters.Counter) internal _nonces;

    /**
     * @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of votes.
     */
    event SenateBooksDelegateVotesChanged(
        address indexed senateMember,
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    /**
     * @dev Read the voting weight from the senate's built in snapshot mechanism.
     * @dev For members that dont implement the SenatorVotes, make a external call to get the voting weight.
     * @dev Quarantined Senators get voting weight zeroed for the duration of quarantine. Banned Senator get no voting weight forever.
     * @dev For members that dont implement the SenatorVotes, quarantine members give no voting weight for the duration of quarantine. Banned Member gets no voting weight forever.
     */
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory /*params*/
    ) internal view virtual override returns (uint256) {
        uint256 totalVotes;

        if (
            senatorBanned.contains(account) ||
            senatorInQuarantine[account] >= (block.number - 1)
        ) return 0;

        totalVotes += _senateBooksCheckpoints[account].getAtProbablyRecentBlock(
                blockNumber
            );

        //call the old dogs
        for (uint256 idx = 0; idx < oldDogsTokens.values().length; idx++) {
            if (
                banned.contains(tokens.values()[idx]) ||
                memberInQuarantine[tokens.values()[idx]] >= (block.number - 1)
            ) continue;

            totalVotes += IVotes(oldDogsTokens.values()[idx]).getPastVotes(
                account,
                block.number - 1
            );
        }

        return totalVotes;
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
        returns (uint256)
    {
        if (
            senatorBanned.contains(account) ||
            senatorInQuarantine[account] >= (block.number - 1)
        ) return 0;

        uint256 totalVotes;

        totalVotes += _senateBooksCheckpoints[account].getAtProbablyRecentBlock(
                blockNumber
            );

        //call the old dogs
        for (uint256 idx = 0; idx < oldDogsTokens.values().length; idx++) {
            if (
                banned.contains(tokens.values()[idx]) ||
                memberInQuarantine[tokens.values()[idx]] >= (block.number - 1)
            ) continue;

            totalVotes += IVotes(oldDogsTokens.values()[idx]).getPastVotes(
                account,
                block.number - 1
            );
        }

        return
            _senateBooksCheckpoints[account].getAtProbablyRecentBlock(
                blockNumber
            );
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

        uint256 _totalSuply;

        _totalSuply += _totalSenateBooksCheckpoints.getAtProbablyRecentBlock(
            blockNumber
        );

        //call the old dogs
        for (uint256 idx = 0; idx < oldDogsTokens.values().length; idx++) {
            if (
                banned.contains(oldDogsTokens.values()[idx]) ||
                memberInQuarantine[oldDogsTokens.values()[idx]] >=
                (block.number - 1)
            ) continue;
            _totalSuply += IVotes(oldDogsTokens.values()[idx])
                .getPastTotalSupply(blockNumber);
        }

        return _totalSuply;
    }

    /**
     * Read the total voting suply at last block mined.
     */
    function _getTotalSuply() internal view virtual override returns (uint256) {
        uint256 _totalSuply;

        _totalSuply += _totalSenateBooksCheckpoints.latest();

        //call the old dogs
        for (uint256 idx = 0; idx < oldDogsTokens.values().length; idx++) {
            if (
                banned.contains(oldDogsTokens.values()[idx]) ||
                memberInQuarantine[oldDogsTokens.values()[idx]] >=
                (block.number - 1)
            ) continue;

            _totalSuply += IVotes(oldDogsTokens.values()[idx])
                .getPastTotalSupply(block.number - 1);
        }

        return _totalSuply;
    }

    //book functions
    /**
     * @dev Transfers, mints, or burns voting units. To register a mint, `from` should be zero. To register a burn, `to`
     * should be zero. Total supply of voting units will be adjusted with mints and burns.
     */
    function _transferVotingUnits(
        address member,
        address from,
        address to,
        uint256 amount,
        bool isSenator
    ) internal virtual override {
        if (from == address(0)) {
            _totalSenateBooksCheckpoints.push(_add, amount);
        }
        if (to == address(0)) {
            _totalSenateBooksCheckpoints.push(_subtract, amount);
        }
        _moveDelegateVotes(member, from, to, amount, isSenator);
    }

    /**
     * @dev Moves delegated votes from one delegate to another.
     */
    function _moveDelegateVotes(
        address member,
        address from,
        address to,
        uint256 amount,
        bool isSenator
    ) private {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _senateBooksCheckpoints[
                    from
                ].push(_subtract, amount);

                if (
                    !isSenator && _senatorRepresentations[from].contains(member)
                ) {
                    _senatorRepresentations[from].remove(member);
                }

                emit SenateBooksDelegateVotesChanged(
                    member,
                    from,
                    oldValue,
                    newValue
                );
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _senateBooksCheckpoints[
                    to
                ].push(_add, amount);

                if (!_senatorRepresentations[to].contains(member))
                    _senatorRepresentations[to].add(member);

                emit SenateBooksDelegateVotesChanged(
                    member,
                    to,
                    oldValue,
                    newValue
                );
            }
        }
    }

    /**
     * @dev Read the senator representations at the latest block
     * @dev For members that dont implement the SenatorVotes, make a external call to get the voting weight.
     * @dev Quarantined Senators get voting weight zeroed for the duration of quarantine. Banned Senator get no voting weight forever.
     * @dev For members that dont implement the SenatorVotes, quarantine members give no voting weight for the duration of quarantine. Banned Member gets no voting weight forever.
     */
    function _getRepresentation(address account)
        internal
        view
        virtual
        override
        returns (address[] memory)
    {
        if (
            senatorBanned.contains(account) ||
            senatorInQuarantine[account] >= (block.number - 1)
        ) return new address[](0);

        address[] memory oldDogRepresentations = new address[](
            oldDogsTokens.length()
        );

        uint256 nextOnList = 0;
        //call the old dogs
        for (uint256 idx = 0; idx < oldDogsTokens.values().length; idx++) {
            if (
                banned.contains(oldDogsTokens.values()[idx]) ||
                memberInQuarantine[oldDogsTokens.values()[idx]] >=
                (block.number - 1)
            ) continue;

            if (
                IVotes(oldDogsTokens.values()[idx]).getPastVotes(
                    account,
                    block.number - 1
                ) > 0
            ) oldDogRepresentations[nextOnList++] = oldDogsTokens.values()[idx];
        }

        address[] memory representations = new address[](
            oldDogsTokens.length() + _senatorRepresentations[account].length()
        );

        nextOnList = 0;
        for (uint256 idx = 0; idx < oldDogRepresentations.length; idx++) {
            representations[nextOnList++] = oldDogRepresentations[idx];
        }

        for (
            uint256 idx = 0;
            idx < _senatorRepresentations[account].length();
            idx++
        ) {
            representations[nextOnList++] = _senatorRepresentations[account].at(
                idx
            );
        }

        return representations;
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
}
