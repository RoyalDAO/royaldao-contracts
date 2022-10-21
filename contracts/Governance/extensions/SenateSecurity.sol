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
abstract contract SenateSecurity is Senate {
    using EnumerableSet for EnumerableSet.AddressSet;
    using BytesArrayLib32 for bytes;

    EnumerableSet.AddressSet internal banned;
    EnumerableSet.AddressSet internal senatorBanned;

    EnumerableSet.AddressSet internal memberInQuarantine;
    EnumerableSet.AddressSet internal senatorInQuarantine;

    mapping(address => uint256) internal memberQuarantine;
    mapping(address => uint256) internal senatorQuarantine;

    uint256 public quarantinePeriod;

    constructor(uint256 _quarantinePeriod) {
        quarantinePeriod = _quarantinePeriod;
    }

    function senateMemberStatus(address _tokenAddress)
        public
        view
        virtual
        override
        returns (membershipStatus)
    {
        if (banned.contains(_tokenAddress)) {
            return membershipStatus.BANNED_MEMBER;
        } else if (memberInQuarantine.contains(_tokenAddress)) {
            return membershipStatus.QUARANTINE_MEMBER;
        } else if (
            tokens.contains(_tokenAddress) ||
            oldDogsTokens.contains(_tokenAddress)
        ) {
            return membershipStatus.ACTIVE_MEMBER;
        } else return membershipStatus.NOT_MEMBER;
    }

    function senatorStatus(address _senator)
        public
        view
        virtual
        override
        returns (senateSenatorStatus)
    {
        if (senatorInQuarantine.contains(_senator)) {
            return senateSenatorStatus.QUARANTINE_SENATOR;
        } else if (senatorBanned.contains(_senator)) {
            return senateSenatorStatus.BANNED_SENATOR;
        } else if (_getVotes(_senator, block.number - 1, "") > 0) {
            return senateSenatorStatus.ACTIVE_SENATOR;
        } else {
            return senateSenatorStatus.NOT_SENATOR;
        }
    }

    /**
     * @dev Check if all members from list are valid.
     */
    function _validateMembers(bytes memory members)
        internal
        view
        virtual
        override
        returns (bool)
    {
        for (uint256 idx = 0; idx < members.count(); idx++) {
            if (!_validateMember(members.getValue(idx))) return false;
        }

        return true;
    }

    /**
     * @dev Check if a given member is valid.
     */
    function _validateMember(uint32 member)
        internal
        view
        virtual
        override
        returns (bool)
    {
        if (
            banned.contains(idMember[member]) ||
            memberInQuarantine.contains(idMember[member])
        ) return false;
        return true;
    }

    /**
     * @dev Check if senator is active.
     */
    function _validateSenator(address senator)
        internal
        view
        virtual
        override
        returns (bool)
    {
        if (
            senatorBanned.contains(senator) ||
            senatorInQuarantine.contains(senator)
        ) return false;

        return true;
    }

    function quarantineFromSenate(address _token)
        external
        virtual
        onlyChancellor
    {
        _quarantineFromSenate(_token);
    }

    function _quarantineFromSenate(address _token) internal virtual {
        require(!banned.contains(_token), "Senate::Already Banned");

        memberQuarantine[_token] = block.number + quarantinePeriod;
        //burn suply from senate books
        _burnMemberVotings(_token);

        memberInQuarantine.add(_token);

        emit MemberQuarantined(_token);
    }

    function unquarantineFromSenate(address _token) external virtual {
        require(
            memberInQuarantine.contains(_token),
            "Senate::Senator Not In Quarantine"
        );
        require(
            memberQuarantine[_token] < block.number,
            "Senate::Quarantine not over"
        );
        require(!banned.contains(_token), "Senate::Already Banned");

        //restore member votes
        _restoreMemberVotings(_token);

        memberInQuarantine.remove(_token);

        emit MemberUnquarantined(_token);
    }

    function _banFromSenate(address _token) internal {
        require(!banned.contains(_token), "Senate::Already Banned");

        banned.add(_token);

        //burn suply from senate books
        _burnMemberVotings(_token);

        emit MemberBanned(_token);
    }

    function quarantineSenator(address _senator)
        external
        virtual
        onlyChancellor
    {
        _quarantineSenator(_senator);
    }

    function _quarantineSenator(address _senator) internal {
        require(
            !senatorInQuarantine.contains(_senator),
            "Senate::Already Quarantined"
        );
        require(!senatorBanned.contains(_senator), "Senate::Already Banned");

        senatorQuarantine[_senator] = block.number + quarantinePeriod;

        _burnSenatorVotings(_senator);

        senatorInQuarantine.add(_senator);

        emit SenatorQuarantined(_senator);
    }

    function unquarantineSenator(address _senator) external virtual {
        require(
            senatorInQuarantine.contains(_senator),
            "Senate::Senator Not In Quarantine"
        );
        require(
            senatorQuarantine[_senator] < block.number,
            "Senate::Quarantine not over"
        );
        require(!senatorBanned.contains(_senator), "Senate::Already Banned");

        //restore senatore votes
        _restoreSenatorVotings(_senator);

        senatorInQuarantine.remove(_senator);

        emit SenatorUnquarantined(_senator);
    }

    function _banSenatorFromSenate(address _senator) internal {
        require(!senatorBanned.contains(_senator), "Senate::Already Banned");

        senatorBanned.add(_senator);

        //burn voting power from senator
        _burnSenatorVotings(_senator);

        emit SenatorBanned(_senator);
    }

    function quarantineUntil(address _token) external view returns (uint256) {
        return memberQuarantine[_token];
    }

    function banFromSenate(address _token) external virtual onlyChancellor {
        _banFromSenate(_token);
    }

    function senatorQuarantineUntil(address _senator)
        external
        view
        returns (uint256)
    {
        return senatorQuarantine[_senator];
    }

    function banSenatorFromSenate(address _senator)
        external
        virtual
        onlyChancellor
    {
        _banSenatorFromSenate(_senator);
    }
}
