// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (governance/extensions/GovernorSettings.sol)

pragma solidity ^0.8.0;

import "../Senate.sol";

/**
 * @dev Extension of {Chancellor} for settings updatable through governance.
 *
 * _Available since v4.4._
 */
abstract contract SenateDeputy is Senate {
    address public deputyMarshal;
    uint256 public mandatePeriod;

    mapping(address => uint256) internal deputyMandate;

    modifier onlyMarshal() {
        require(msg.sender == deputyMarshal, "Senate::Only deputy allowed!");
        _;
    }

    /**
     * @dev Initialize the governance parameters.
     */
    constructor(address _deputyMarshal, uint256 _mandatePeriod) {
        //set deputy mandate
        mandatePeriod = _mandatePeriod;
        _setNewDeputyMarshal(_deputyMarshal);
    }

    function changeDeputyMarshal(address _newMarshalInTown)
        external
        virtual
        onlyChancellor
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
}
