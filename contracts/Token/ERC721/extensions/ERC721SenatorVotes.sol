// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/extensions/draft-ERC721Votes.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../../../Governance/utils/SenatorVotes.sol";
import "../../../Governance/utils/ISenatorVotes.sol";
import "../../../Governance/ISenate.sol";

/**
 * @dev Extension of Openzeppelin's {ERC721} to support voting and delegation as implemented by {SenatorVotes}, where each individual NFT counts
 * as 1 vote unit.
 *
 * ERC721SenatorVotes.sol modifies OpenZeppelin's ERC721Votes.sol:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Votes.sol
 * ERC721Votes.sol source code copyright OpenZeppelin licensed under the MIT License.
 * Modified by RoyalDAO.
 *
 * CHANGES: - Adapted to work with the {Senate}, informing support of {ISenatorVotes} interface so the senate can recognize 
              the token voting control implementation type.
            - Inheritage of SenatorVotes pattern
            
 * _Available since v1.0._
 */
abstract contract ERC721SenatorVotes is ERC721, SenatorVotes {
    constructor(ISenate _senate) SenatorVotes(_senate) {}

    /**
     * @dev Adjusts votes when tokens are transferred.
     *
     * Emits a {Votes-DelegateVotesChanged} event.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        _transferVotingUnits(from, to, 1);

        super._afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Returns the balance of `account`.
     */
    function _getVotingUnits(address account)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return balanceOf(account);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(ISenatorVotes).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
