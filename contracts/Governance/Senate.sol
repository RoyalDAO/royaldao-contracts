// SPDX-License-Identifier: MIT
// RoyalDAO Contracts (last updated v1.1.1) (Governance/Senate.sol)
// Uses OpenZeppelin Contracts and Libraries

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./ISenate.sol";
import "../Governance/utils/ISenatorVotes.sol";
import "../Utils/ArrayBytes.sol";

/**
 * @dev Contract made to handle multiple tokens as members of the same DAO.
 *
 * _Available since v1.1._
 *
 */
//TODO: Senate member withdraw from senate
abstract contract Senate is Context, ERC165, EIP712, ISenate {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;
    using BytesArrayLib32 for bytes;

    /**
     * @dev storage for members that implements ERC721SenatorVotes
     * @dev ERC721SenatorVotes implementers have function that don't exists in ERC721Votes implementers
     */
    EnumerableSet.AddressSet internal tokens;

    /**
     * @dev storage for members that implements ERC721Votes
     */
    EnumerableSet.AddressSet internal oldDogsTokens;

    /**
     * @dev address of DAO Executor (If uses TimeLock, should be TimeLock address. Chancellor address otherwise).
     */
    address public Chancellor;

    /**
     * @dev generator of sequential member ids.
     */
    Counters.Counter internal memberCounter;

    /**
     * @dev mappings to manage translation Member Address <--> Member Id.
     */
    mapping(address => uint32) internal memberId;
    mapping(uint32 => address) internal idMember;

    /**
     * @dev EIP712 _name storage
     */
    string private _name;

    /**
     * @dev Modifier to ensure that caller is Chancellor
     */
    modifier onlyChancellor() {
        require(msg.sender == Chancellor, "Senate::Only Chancellor allowed!");
        _;
    }

    /**
     * @dev Modifier to ensure that Senate is Open
     */
    modifier ifSenateOpen() {
        require(
            tokens.length() > 0 || oldDogsTokens.length() > 0,
            "Senate::Senate Not Open!"
        );
        _;
    }

    /**
     * @dev Modifier to ensure that Senate is Closed
     */
    modifier ifSenateClosed() {
        require(
            tokens.length() == 0 && oldDogsTokens.length() == 0,
            "Senate::Senate Already Open!"
        );
        _;
    }

    /**
     * @dev Modifier to ensure that Member is accepted part of the Senate
     */
    modifier onlyValidMember() {
        require(
            senateMemberStatus(msg.sender) == membershipStatus.ACTIVE_MEMBER,
            "Senate::Invalid Senate Member"
        );
        _;
    }

    /**
     * @dev Senate constructor must receive a valida deployed Chancellor contract address
     */
    constructor(string memory name_, address _Chancellor)
        EIP712(name_, version())
    {
        require(
            _Chancellor != address(0),
            "Senate::Invalid Chancellor address(0)"
        );

        Chancellor = _Chancellor;
        _name = name_;
    }

    /**
     * @dev See {ISenate-openSenate}.
     */
    function openSenate(address[] memory _tokens)
        external
        override
        ifSenateClosed
    {
        for (uint256 idx = 0; idx < _tokens.length; idx++) {
            if (
                IERC165(_tokens[idx]).supportsInterface(
                    type(ISenatorVotes).interfaceId
                )
            ) {
                if (!tokens.contains(_tokens[idx])) {
                    memberCounter.increment();
                    memberId[_tokens[idx]] = SafeCast.toUint32(
                        memberCounter.current()
                    );
                    idMember[
                        SafeCast.toUint32(memberCounter.current())
                    ] = _tokens[idx];

                    tokens.add(_tokens[idx]);
                }
            } else if (
                IERC165(_tokens[idx]).supportsInterface(
                    type(IVotes).interfaceId
                )
            ) {
                if (!oldDogsTokens.contains(_tokens[idx])) {
                    memberCounter.increment();
                    memberId[_tokens[idx]] = SafeCast.toUint32(
                        memberCounter.current()
                    );
                    idMember[
                        SafeCast.toUint32(memberCounter.current())
                    ] = _tokens[idx];

                    oldDogsTokens.add(_tokens[idx]);
                }
            } else revert("SenateUpgradeable::Invalid implementation!");
        }
    }

    /**
     * @dev Get the voting weight of `account` at a specific `blockNumber`, for a vote as described by `params` from senate books.
     */
    function getVotes(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) external view virtual returns (uint256) {
        return _getVotes(account, blockNumber, params);
    }

    /**
     * @dev Get the total voting supply from senate books at latest `blockNumber`.
     */
    function getTotalSuply() external view virtual returns (uint256) {
        return _getTotalSuply();
    }

    /**
     * @dev See {ISenate-transferVotingUnits}.
     */
    function transferVotingUnits(
        address from,
        address to,
        uint256 amount,
        bool isSenator,
        bool updateTotalSupply
    ) external virtual override onlyValidMember {
        _transferVotingUnits(
            msg.sender,
            from,
            to,
            amount,
            isSenator,
            updateTotalSupply
        );
    }

    /**
     * @dev See {ISenate-getRepresentation}.
     */
    function getRepresentation(address account)
        external
        view
        virtual
        override
        returns (bytes memory)
    {
        return _getRepresentation(account);
    }

    /**
     * @dev Get the current senator representation readable list
     */
    function getRepresentationList(address account)
        external
        view
        virtual
        returns (uint32[] memory)
    {
        return _getRepresentation(account).getArray();
    }

    /**
     * @dev Accept new Member to Senate from approved proposal
     */
    function acceptToSenate(address _token) external virtual onlyChancellor {
        _acceptToSenate(_token);
    }

    function getNewGang() external view returns (address[] memory) {
        return tokens.values();
    }

    /**
     * @dev Get the current IVotes Implementers Member List
     */
    function getOldDogs() external view returns (address[] memory) {
        return oldDogsTokens.values();
    }

    /**
     * @dev Get the Member Id for given Member address
     */
    function getMemberId(address member) external view returns (uint32) {
        return memberId[member];
    }

    /**
     * @dev Get the Member address with given Id
     */
    function getMemberOfId(uint32 _memberId) external view returns (address) {
        return idMember[_memberId];
    }

    /**
     * @dev {ISenate-validateMembers}.
     */
    function validateMembers(bytes memory members)
        external
        view
        virtual
        override
        returns (bool)
    {
        return _validateMembers(members);
    }

    /**
     * @dev {ISenate-validateSenator}.
     */
    function validateSenator(address senator)
        external
        view
        virtual
        override
        returns (bool)
    {
        return _validateSenator(senator);
    }

    /**
     * @dev Return current Senate Settings. Must implement it if not using SenateSettings Extension.
     */
    function getSettings(address account)
        external
        view
        virtual
        returns (
            uint256 proposalThreshold,
            uint256 votingDelay,
            uint256 votingPeriod,
            bytes memory senatorRepresentations,
            uint256 votingPower,
            bool validSenator,
            bool validMembers
        );

    /**
     * @dev See {ISenate-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {ISenate-version}.
     */
    function version() public view virtual override returns (string memory) {
        return "1";
    }

    /**
     * @dev Part of the Chancellor Bravo's interface: _"The number of votes required in order for a voter to become a proposer"_.
     */
    function proposalThreshold() public view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC165)
        returns (bool)
    {
        return
            interfaceId == type(ISenate).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev {ISenate-senateMemberStatus}.
     */
    function senateMemberStatus(address _tokenAddress)
        public
        view
        virtual
        override
        returns (membershipStatus);

    /**
     * @dev {ISenate-senatorStatus}.
     */
    function senatorStatus(address _senator)
        public
        view
        virtual
        override
        returns (senateSenatorStatus);

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
        returns (uint256);

    /**
     * @dev internal function to process new member entrance
     */
    function _acceptToSenate(address _token) internal {
        //require(!banned.contains(_token), "Senate::Banned are Exiled");
        require(
            senateMemberStatus(_token) != membershipStatus.BANNED_MEMBER,
            "Senate::Banned are Exiled"
        );

        if (
            IERC165(_token).supportsInterface(type(ISenatorVotes).interfaceId)
        ) {
            if (!tokens.contains(_token)) {
                memberCounter.increment();
                memberId[_token] = SafeCast.toUint32(memberCounter.current());
                idMember[SafeCast.toUint32(memberCounter.current())] = _token;

                tokens.add(_token);
                //must sync senate books
                writeMemberToSenateBooks(_token);
            }
        } else if (
            IERC165(_token).supportsInterface(type(IVotes).interfaceId)
        ) {
            if (!oldDogsTokens.contains(_token)) {
                memberCounter.increment();
                memberId[_token] = SafeCast.toUint32(memberCounter.current());
                idMember[SafeCast.toUint32(memberCounter.current())] = _token;

                oldDogsTokens.add(_token);
            }
        } else revert("Senate::Invalid implementation!");
    }

    /**
     * @dev Check if all members from list are valid.
     */
    function _validateMembers(bytes memory members)
        internal
        view
        virtual
        returns (bool);

    /**
     * @dev Check if a given member is valid.
     */
    function _validateMember(uint32 member)
        internal
        view
        virtual
        returns (bool);

    /**
     * @dev Check if senator is active.
     */
    function _validateSenator(address senator)
        internal
        view
        virtual
        returns (bool);

    /**
     * @dev Get the voting weight of `account` at a specific `blockNumber`, for a vote as described by `params`.
     * @dev Overriden by SenateVotes extension.
     * @dev If not using SenateVotes extension, must implement.
     */
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) internal view virtual returns (uint256);

    /**
     * @dev Get total voting suply until last block.
     * @dev Overriden by SenateVotes extension.
     * @dev If not using SenateVotes extension, must implement.
     */
    function _getTotalSuply() internal view virtual returns (uint256);

    /**
     * @dev Get the Senator Representations
     * @dev Representation is a list of the Members(tokens) from whom the Senator owns 1 or more tokens
     */
    function _getRepresentation(address account)
        internal
        view
        virtual
        returns (bytes memory);

    /**
     * @dev Transfers, mints, or burns voting units. To register a mint, `from` should be zero. To register a burn, `to`
     * should be zero. Total supply of voting units will be adjusted with mints and burns.
     * @dev Overriden by SenateVotes extension.
     * @dev If not using SenateVotes extension, must implement.
     */
    function _transferVotingUnits(
        address member,
        address from,
        address to,
        uint256 amount,
        bool isSenator,
        bool updateTotalSupply
    ) internal virtual;

    /**
     * @dev Burn suply of given member that was banished or quarantined
     */
    function _burnMemberVotings(address member) internal virtual;

    /**
     * @dev Burn suply of given senator that was banished or quarantined
     */
    function _burnSenatorVotings(address _senator) internal virtual;

    /**
     * @dev Recover suply of given senator that is getting out of quarantine
     */
    function _restoreSenatorVotings(address _senator) internal virtual;

    /**
     * @dev Recover suply of given member that is getting out of quarantine
     */
    function _restoreMemberVotings(address _token) internal virtual;

    /**
     *@dev writes the voting distribution of a Member that enters the senate after its opening
     *
     *NOTE: this function only works for SenatorVotes implementers
     */
    function writeMemberToSenateBooks(address member) private {
        //get owners list
        ISenatorVotes.senateSnapshot[] memory _totalSuply = ISenatorVotes(
            member
        ).getSenateSnapshot();

        for (uint256 idx = 0; idx < _totalSuply.length; idx++) {
            _transferVotingUnits(
                member,
                address(0),
                _totalSuply[idx].senator,
                _totalSuply[idx].votes,
                true,
                true
            );
        }
    }
}
