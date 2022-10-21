// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./ISenate.sol";
import "../Governance/utils/ISenatorVotes.sol";
import "../Utils/ArrayBytes.sol";

/**
 * @dev Extension of {Governor} for voting weight extraction from an {ERC20Votes} token, or since v4.5 an {ERC721Votes} token.
 *
 * _Available since v4.3._
 *
 * @custom:storage-size 51
 */
abstract contract Senate is Context, ERC165, EIP712, ISenate {
    //TODO: Complex votes for single vote by token
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;
    using BytesArrayLib32 for bytes;

    EnumerableSet.AddressSet internal tokens;
    EnumerableSet.AddressSet internal oldDogsTokens;

    address public Chancellor;

    Counters.Counter private memberCounter;

    mapping(address => uint32) internal memberId;
    mapping(uint32 => address) internal idMember;

    string private _name;

    modifier onlyChancellor() {
        require(msg.sender == Chancellor, "Senate::Only Chancellor allowed!");
        _;
    }

    modifier ifSenateOpen() {
        require(
            tokens.length() > 0 || oldDogsTokens.length() > 0,
            "Senate::Senate Not Open!"
        );
        _;
    }

    modifier ifSenateClosed() {
        require(
            tokens.length() == 0 && oldDogsTokens.length() == 0,
            "Senate::Senate Already Open!"
        );
        _;
    }

    modifier onlyValidMember() {
        require(
            senateMemberStatus(msg.sender) == membershipStatus.ACTIVE_MEMBER,
            "Senate::Invalid Senate Member"
        );
        _;
    }

    constructor(string memory name_, address _Chancellor)
        EIP712(name_, version())
    {
        //quarantinePeriod = _quarantinePeriod;

        Chancellor = _Chancellor;
        _name = name_;
    }

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

    function openSenate(address[] memory _tokens)
        external
        virtual
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
     * @dev Default additional encoded parameters used by castVote methods that don't include them
     *
     * Note: Should be overridden by specific implementations to use an appropriate value, the
     * meaning of the additional params, in the context of that implementation
     */
    function _defaultParams() internal view virtual returns (bytes memory) {
        return "";
    }

    function getNewGang() external view returns (address[] memory) {
        return tokens.values();
    }

    function getOldDogs() external view returns (address[] memory) {
        return oldDogsTokens.values();
    }

    function getMemberId(address member) external view returns (uint32) {
        return memberId[member];
    }

    function getMemberOfId(uint32 _memberId) external view returns (address) {
        return idMember[_memberId];
    }

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
                true
            );
        }
    }

    /**
     * @dev Check if all members from list are valid.
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
     * @dev Check if senator is active.
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
     * @dev Part of the Chancellor Bravo's interface: _"The number of votes required in order for a voter to become a proposer"_.
     */
    function proposalThreshold() public view virtual returns (uint256) {
        return 0;
    }

    function acceptToSenate(address _token) external virtual onlyChancellor {
        _acceptToSenate(_token);
    }

    /**
     * @dev Get the voting weight of `account` at a specific `blockNumber`, for a vote as described by `params`.
     */
    function getVotes(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) external view virtual returns (uint256) {
        require(
            _validateMembers(_getRepresentation(account)),
            "Senate::Senator Owns token from Inapt Member"
        );

        return _getVotes(account, blockNumber, params);
    }

    /**
     * @dev Get the total voting supply at latest `blockNumber`.
     */
    function getTotalSuply() external view virtual returns (uint256) {
        return _getTotalSuply();
    }

    /**
     * @dev Update Senate Voting Books.
     */
    function transferVotingUnits(
        address from,
        address to,
        uint256 amount,
        bool isSenator
    ) external virtual override onlyValidMember {
        _transferVotingUnits(msg.sender, from, to, amount, isSenator);
    }

    /**
     * @dev Get the current senator representation in bytes.
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
     * @dev Get the current senator representation in bytes.
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

    /*** \/ Functions that contract must implement ******************************************************************/

    function senateMemberStatus(address _tokenAddress)
        public
        view
        virtual
        override
        returns (membershipStatus);

    function senatorStatus(address _senator)
        public
        view
        virtual
        override
        returns (senateSenatorStatus);

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

    function getPastTotalSupply(uint256 blockNumber)
        public
        view
        virtual
        returns (uint256);

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
        bool isSenator
    ) internal virtual;

    //book functions
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

    /*** /\ Functions that contract must implement ******************************************************************/
}
