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
import "./ISenate.sol";
import "../Governance/utils/ISenatorVotes.sol";

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

    EnumerableSet.AddressSet internal tokens;
    EnumerableSet.AddressSet internal oldDogsTokens;
    EnumerableSet.AddressSet internal banned;
    EnumerableSet.AddressSet internal senatorBanned;

    address internal deputyMarshal;
    address internal chancelor;

    uint256 public mandatePeriod;
    mapping(address => uint256) internal deputyMandate;
    uint256 public quarantinePeriod;
    mapping(address => uint256) internal memberInQuarantine;
    mapping(address => uint256) internal senatorInQuarantine;

    string private _name;

    modifier onlyMarshal() {
        require(msg.sender == deputyMarshal, "Senate::Only deputy allowed!");
        _;
    }

    modifier onlyChancelor() {
        require(msg.sender == chancelor, "Senate::Only Chancelor allowed!");
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

    constructor(
        string memory name_,
        address _deputyMarshal,
        uint256 _mandatePeriod,
        address _chancelor,
        uint256 _quarantinePeriod
    ) EIP712(name_, version()) {
        quarantinePeriod = _quarantinePeriod;

        //set deputy mandate
        mandatePeriod = _mandatePeriod;
        _setNewDeputyMarshal(_deputyMarshal);

        chancelor = _chancelor;
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
        onlyMarshal
        ifSenateClosed
    {
        for (uint256 idx = 0; idx < _tokens.length; idx++) {
            if (
                IERC165(_tokens[idx]).supportsInterface(
                    type(ISenatorVotes).interfaceId
                )
            ) {
                if (!tokens.contains(_tokens[idx])) tokens.add(_tokens[idx]);
            } else if (
                IERC165(_tokens[idx]).supportsInterface(
                    type(IVotes).interfaceId
                ) ||
                IERC165(_tokens[idx]).supportsInterface(
                    type(IVotes).interfaceId
                )
            ) {
                if (!oldDogsTokens.contains(_tokens[idx]))
                    oldDogsTokens.add(_tokens[idx]);
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

    function getNewGang() public view returns (address[] memory) {
        return tokens.values();
    }

    function getOldDogs() public view returns (address[] memory) {
        return oldDogsTokens.values();
    }

    function senateMemberStatus(address _tokenAddress)
        public
        view
        returns (membershipStatus)
    {
        if (memberInQuarantine[_tokenAddress] >= block.number) {
            return membershipStatus.QUARANTINE_MEMBER;
        } else if (banned.contains(_tokenAddress)) {
            return membershipStatus.BANNED_MEMBER;
        } else if (
            tokens.contains(_tokenAddress) ||
            oldDogsTokens.contains(_tokenAddress)
        ) {
            return membershipStatus.ACTIVE_MEMBER;
        } else return membershipStatus.NOT_MEMBER;
    }

    function changeDeputyMarshal(address _newMarshalInTown)
        external
        virtual
        override
        onlyChancelor
    {
        _setNewDeputyMarshal(_newMarshalInTown);
    }

    function _setNewDeputyMarshal(address _newMarshalInTown) internal {
        require(
            deputyMandate[deputyMarshal] < block.number,
            "Senate::Mandate not ended!"
        );

        deputyMarshal = _newMarshalInTown;
        //set deputy mandate
        deputyMandate[deputyMarshal] = block.number + mandatePeriod;

        emit NewDeputyInTown(_newMarshalInTown, block.number + mandatePeriod);
    }

    function deputyResignation(address _currentDeputy)
        external
        virtual
        onlyMarshal
    {
        //set deputy final mandate block
        deputyMandate[_currentDeputy] = block.number;

        emit DeputyResignation(_currentDeputy, block.number);
    }

    function acceptToSenate(address _token) public virtual onlyChancelor {
        _acceptToSenate(_token);
    }

    function _acceptToSenate(address _token) internal {
        require(!banned.contains(_token), "Senate::Banned are Exiled");

        if (
            IERC165(_token).supportsInterface(type(ISenatorVotes).interfaceId)
        ) {
            if (!tokens.contains(_token)) {
                tokens.add(_token);
                //must sync senate books
                writeMemberToSenateBooks(_token);
            }
        } else if (
            IERC165(_token).supportsInterface(type(IVotes).interfaceId)
        ) {
            if (!oldDogsTokens.contains(_token)) oldDogsTokens.add(_token);
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

    function quarantineFromSenate(address _token) public virtual onlyMarshal {
        _quarantineFromSenate(_token);
    }

    function _quarantineFromSenate(address _token) internal {
        require(!banned.contains(_token), "SenateUpgradeable::Already Banned");

        memberInQuarantine[_token] = block.number + quarantinePeriod;

        emit MemberQuarantined(_token);
    }

    function quarantineUntil(address _token) external view returns (uint256) {
        return memberInQuarantine[_token];
    }

    function banFromSenate(address _token) public virtual onlyChancelor {
        _banFromSenate(_token);
    }

    function _banFromSenate(address _token) internal {
        require(!banned.contains(_token), "SenateUpgradeable::Already Banned");

        if (tokens.contains(_token)) tokens.remove(_token);

        banned.add(_token);

        emit MemberBanned(_token);
    }

    function quarantineSenator(address _senator) public virtual onlyMarshal {
        _quarantineSenator(_senator);
    }

    function _quarantineSenator(address _senator) internal {
        require(
            !senatorBanned.contains(_senator),
            "SenateUpgradeable::Already Banned"
        );

        senatorInQuarantine[_senator] = block.number + quarantinePeriod;

        emit SenatorQuarantined(_senator);
    }

    function senatorQuarantineUntil(address _senator)
        external
        view
        returns (uint256)
    {
        return senatorInQuarantine[_senator];
    }

    function banSenatorFromSenate(address _senator)
        public
        virtual
        onlyChancelor
    {
        _banSenatorFromSenate(_senator);
    }

    function _banSenatorFromSenate(address _senator) internal {
        require(
            !senatorBanned.contains(_senator),
            "SenateUpgradeable::Already Banned"
        );

        senatorBanned.add(_senator);

        emit SenatorBanned(_senator);
    }

    /**
     * @dev Part of the Chancelor Bravo's interface: _"The number of votes required in order for a voter to become a proposer"_.
     */
    function proposalThreshold() public view virtual returns (uint256) {
        return 0;
    }

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

    //book functions
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

    /**
     * @dev Get the voting weight of `account` at a specific `blockNumber`, for a vote as described by `params`.
     */
    function getVotes(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) external view virtual returns (uint256) {
        return _getVotes(account, blockNumber, params);
    }

    /**
     * @dev Get the total voting supply at last `blockNumber`.
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

    function getSettings(address account)
        external
        view
        virtual
        returns (
            uint256 proposalThreshold,
            uint256 votingDelay,
            uint256 votingPeriod,
            address[] memory senatorRepresentations
        );

    function _getRepresentation(address account)
        internal
        view
        virtual
        returns (address[] memory);

    /**
     * @dev Get the current senator representation.
     */
    function getRepresentation(address account)
        external
        view
        virtual
        returns (address[] memory)
    {
        return _getRepresentation(account);
    }

    /**
     * @dev Check if all members from list are valid.
     */
    function validateMembers(address[] calldata members)
        external
        view
        virtual
        override
        returns (bool)
    {
        for (uint256 idx = 0; idx < members.length; idx++) {
            if (
                (!tokens.contains(members[idx]) &&
                    !oldDogsTokens.contains(members[idx])) ||
                banned.contains(members[idx]) ||
                memberInQuarantine[members[idx]] >= block.number
            ) return false;
        }
        return true;
    }

    /**
     * @dev Check if senator is active.
     */
    function validateSenator(address senator)
        public
        view
        virtual
        override
        returns (bool)
    {
        if (
            senatorBanned.contains(senator) ||
            senatorInQuarantine[senator] >= block.number
        ) return false;

        return true;
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
}
