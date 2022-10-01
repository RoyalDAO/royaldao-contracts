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
    //TODO: Control representation on proposal (proposer is representing Who?)
    //TODO: Block execution of proposals representating quarantine members
    //TODO: Block execution of proposals representating banned members
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal tokens;
    EnumerableSet.AddressSet internal oldDogsTokens;
    EnumerableSet.AddressSet internal banned;

    address internal marshalDeputy;
    address internal chancelor;

    uint256 quarantinePeriod;
    mapping(address => uint256) internal quarantine;

    string private _name;

    modifier onlyMarshal() {
        require(msg.sender == marshalDeputy, "Senate::Only deputy allowed!");
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
        address _marshalDeputy,
        address _chancelor,
        uint256 _quarantinePeriod
    ) EIP712(name_, version()) {
        quarantinePeriod = _quarantinePeriod;
        marshalDeputy = _marshalDeputy;
        chancelor = _chancelor;
        _name = name_;
    }

    /**
     * @dev See {IChancelor-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IChancelor-version}.
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
        if (quarantine[_tokenAddress] >= block.number) {
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

    function changeMarshalDeputy(address _newMarshalInTown) public virtual {
        _setNewMarshalDeputy(_newMarshalInTown);
    }

    function _setNewMarshalDeputy(address _newMarshalInTown) internal {
        marshalDeputy = _newMarshalInTown;
    }

    function acceptToSenate(address _token) public virtual onlyChancelor {
        _acceptToSenate(_token);
    }

    function _acceptToSenate(address _token) internal {
        require(
            !banned.contains(_token),
            "SenateUpgradeable::Banned are Exiled"
        );

        if (
            IERC165(_token).supportsInterface(type(ISenatorVotes).interfaceId)
        ) {
            if (!tokens.contains(_token)) tokens.add(address(_token));
        } else if (
            IERC165(_token).supportsInterface(type(IVotes).interfaceId)
        ) {
            if (!oldDogsTokens.contains(_token))
                oldDogsTokens.add(address(_token));
        } else revert("SenateUpgradeable::Invalid implementation!");
    }

    function quarantineFromSenate(address _token) public virtual onlyMarshal {
        _quarantineFromSenate(_token);
    }

    function _quarantineFromSenate(address _token) internal {
        require(!banned.contains(_token), "SenateUpgradeable::Already Banned");

        quarantine[_token] = block.number + quarantinePeriod;
    }

    function quarantineUntil(address _token) external view returns (uint256) {
        return quarantine[_token];
    }

    function banFromSenate(address _token) public virtual onlyChancelor {
        _banFromSenate(_token);
    }

    function _banFromSenate(address _token) internal {
        require(!banned.contains(_token), "SenateUpgradeable::Already Banned");

        if (tokens.contains(_token)) tokens.remove(_token);

        banned.add(_token);
    }

    /**
     * @dev Part of the Chancelor Bravo's interface: _"The number of votes required in order for a voter to become a proposer"_.
     */
    function proposalThreshold() public view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Get the voting weight of `account` at a specific `blockNumber`, for a vote as described by `params`.
     */
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) internal view virtual returns (uint256);

    /**
     * @dev Get total voting suply until last block.
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
     */
    function _transferVotingUnits(
        address member,
        address from,
        address to,
        uint256 amount
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
        uint256 amount
    ) external virtual override onlyValidMember {
        _transferVotingUnits(msg.sender, from, to, amount);
    }

    function getSettings()
        external
        view
        virtual
        returns (
            uint256 proposalThreshold,
            uint256 votingDelay,
            uint256 votingPeriod
        );

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
        // In addition to the current interfaceId, also support previous version of the interfaceId that did not
        // include the castVoteWithReasonAndParams() function as standard
        return
            interfaceId == type(ISenate).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
