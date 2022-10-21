// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.0;

import "../Senate.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../Governance/utils/ISenatorVotes.sol";
import "../../Utils/Checkpoints.sol";
import "../../Utils/ArrayBytes.sol";

/**
 * @dev Extension of {Senate} for voting weight extraction from an {ERC721Votes} token.
 *
 */
abstract contract SenateVotes is Senate {
    //TODO: Complex votes for single vote by token
    using EnumerableSet for EnumerableSet.AddressSet;
    using Checkpoints for Checkpoints.History;
    using Counters for Counters.Counter;
    using BytesArrayLib32 for bytes;

    /**
     * @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of votes.
     */
    event SenateBooksDelegateVotesChanged(
        address indexed senateMember,
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    /*********************************************** \/ Contract State *****************************************/

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => Checkpoints.History) internal _senateBooksCheckpoints;

    Checkpoints.History internal _totalSenateBooksCheckpoints;
    //senator representations
    mapping(address => bytes) internal _senatorRepresentationsBytes;

    mapping(address => Counters.Counter) internal _nonces;

    /*********************************************** /\ Contract State *****************************************/

    /*********************************************** \/ Votes Calculation ***********************************************/

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
        require(
            _validateMembers(_senatorRepresentationsBytes[account]),
            "SenateVotes::Representing Inapt Members"
        );

        if (!_validateSenator(account)) return 0;

        uint256 totalVotes;

        totalVotes += _senateBooksCheckpoints[account].getAtProbablyRecentBlock(
                blockNumber
            );

        if (oldDogsTokens.length() <= 0) return totalVotes;

        //call the old dogs
        for (uint256 idx = 0; idx < oldDogsTokens.values().length; idx++) {
            if (!_validateMember(memberId[oldDogsTokens.values()[idx]]))
                continue;

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
        if (!_validateSenator(account)) return 0;

        uint256 totalVotes;

        totalVotes += _senateBooksCheckpoints[account].getAtProbablyRecentBlock(
                blockNumber
            );

        if (oldDogsTokens.length() <= 0) return totalVotes;

        //call the old dogs
        for (uint256 idx = 0; idx < oldDogsTokens.values().length; idx++) {
            if (!_validateMember(memberId[oldDogsTokens.values()[idx]]))
                continue;

            totalVotes += IVotes(oldDogsTokens.values()[idx]).getPastVotes(
                account,
                block.number - 1
            );
        }

        return totalVotes;
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
            if (!_validateMember(memberId[oldDogsTokens.at(idx)])) continue;
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
            if (!_validateMember(memberId[oldDogsTokens.at(idx)])) continue;

            _totalSuply += IVotes(oldDogsTokens.values()[idx])
                .getPastTotalSupply(block.number - 1);
        }

        return _totalSuply;
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
        returns (bytes memory)
    {
        bytes memory representationBytes;
        if (!_validateSenator(account)) return representationBytes;

        representationBytes = _senatorRepresentationsBytes[account];

        if (oldDogsTokens.length() == 0) {
            return representationBytes;
        }

        //call the old dogs
        for (uint256 idx = 0; idx < oldDogsTokens.values().length; idx++) {
            if (!_validateMember(memberId[oldDogsTokens.at(idx)])) continue;

            if (
                IVotes(oldDogsTokens.values()[idx]).getPastVotes(
                    account,
                    block.number - 1
                ) > 0
            )
                representationBytes = representationBytes.insert(
                    memberId[oldDogsTokens.values()[idx]]
                );
        }

        return representationBytes;
    }

    /*********************************************** /\ Votes Calculation ***********************************************/

    /*********************************************** \/ Senate Book Maintenance *****************************************/

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
        if (
            from == address(0) &&
            _validateSenator(from) &&
            _validateMember(memberId[member])
        ) {
            _totalSenateBooksCheckpoints.push(_add, amount);
        }
        if (
            to == address(0) &&
            _validateSenator(to) &&
            _validateMember(memberId[member])
        ) {
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
            uint32 _memberId = memberId[member];

            if (from != address(0) && _validateSenator(from)) {
                (uint256 oldValue, uint256 newValue) = _senateBooksCheckpoints[
                    from
                ].push(_subtract, amount);

                if (!isSenator) {
                    _senatorRepresentationsBytes[
                        from
                    ] = _senatorRepresentationsBytes[from].remove(_memberId);
                }

                emit SenateBooksDelegateVotesChanged(
                    member,
                    from,
                    oldValue,
                    newValue
                );
            }
            if (to != address(0) && _validateSenator(to)) {
                (uint256 oldValue, uint256 newValue) = _senateBooksCheckpoints[
                    to
                ].push(_add, amount);

                _senatorRepresentationsBytes[to].insertStorage(_memberId);

                emit SenateBooksDelegateVotesChanged(
                    member,
                    to,
                    oldValue,
                    newValue
                );
            }
        }
    }

    //book functions
    /**
     * @dev Burn suply of given member that was banished or quarantined
     */
    function _burnMemberVotings(address member) internal virtual override {
        require(
            !_validateMember(memberId[member]),
            "SenateVotes::Member not banned nor quarantined"
        );

        if (tokens.contains(member))
            _totalSenateBooksCheckpoints.push(
                _subtract,
                ISenatorVotes(member).getTotalSupply()
            );

        //if (!_banned) memberInQuarantine.add(member);
    }

    /**
     * @dev Burn suply of given senator that was banished or quarantined
     */
    function _burnSenatorVotings(address _senator) internal virtual override {
        require(
            _validateSenator(_senator),
            "SenateVotes::Senator not banned nor quarantined"
        );

        //burn senator votes for the time being
        uint256 senatorVotes = _senateBooksCheckpoints[_senator]
            .getAtProbablyRecentBlock(block.number - 1);

        if (senatorVotes > 0) {
            //burn senator votes
            _transferVotingUnits(
                address(0),
                _senator,
                address(0),
                senatorVotes,
                false
            );
        }

        //add to storage so we know when we need to free senator from quarantine
        //if (!_banned) senatorInQuarantine.add(_senator);
    }

    /**
     * @dev Recover suply of given senator that is getting out of quarantine
     */
    function _restoreSenatorVotings(address _senator)
        internal
        virtual
        override
    {
        //require(
        //    !senatorBanned.contains(_senator),
        //    "SenateVotes::Senator banned"
        //);
        require(
            senatorStatus(_senator) != senateSenatorStatus.BANNED_SENATOR,
            "SenateVotes::Senator banned"
        );

        //require(
        //    senatorInQuarantine.contains(_senator),
        //    "SenateVotes::Senator not in quarantine"
        //);
        require(
            senatorStatus(_senator) == senateSenatorStatus.QUARANTINE_SENATOR,
            "SenateVotes::Senator not in quarantine"
        );

        //revert(
        //    Strings.toHexString(uint160(senatorInQuarantine.getAddress(0)), 20)
        //);

        //get senator out of quarantine
        //senatorInQuarantine.remove(_senator);

        for (uint256 idx = 0; idx < tokens.length(); idx++) {
            uint256 senatorVotes = ISenatorVotes(tokens.at(idx)).getPastVotes(
                _senator,
                block.number - 1
            );

            if (senatorVotes > 0)
                _transferVotingUnits(
                    tokens.at(idx),
                    address(0),
                    _senator,
                    senatorVotes,
                    true
                );
        }
    }

    /**
     * @dev Recover suply of given member that is getting out of quarantine
     */
    function _restoreMemberVotings(address _token) internal virtual override {
        require(
            senateMemberStatus(_token) != membershipStatus.BANNED_MEMBER,
            "SenateVotes::Senator banned"
        );

        require(
            senateMemberStatus(_token) == membershipStatus.QUARANTINE_MEMBER,
            "SenateVotes::Member not in quarantine"
        );

        //get senator out of quarantine
        //memberInQuarantine.remove(_token);

        uint256 memberVotes = ISenatorVotes(_token).getTotalSupply();

        if (memberVotes > 0)
            _totalSenateBooksCheckpoints.push(_add, memberVotes);
    }

    /*********************************************** /\ Senate Book Maintenance *****************************************/

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
