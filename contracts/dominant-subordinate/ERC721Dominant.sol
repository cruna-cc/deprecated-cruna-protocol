// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IERC721Subordinate.sol";
import "./IERC721Dominant.sol";

/// @dev ERC721Dominant is an abstract contract that represents a dominant NFT.
///  It inherits from the standard ERC721 contract and adds functionality for managing subordinate NFTs.
abstract contract ERC721Dominant is IERC721Dominant, ERC721, ReentrancyGuard {
  error NotOwnedByDominant(address subordinate, address dominant);
  error NotASubordinate(address subordinate);

  /// @dev The ID for the next subordinate to be added.
  uint256 private _nextSubordinateId;

  /// @dev Mapping of subordinate IDs to their corresponding contract addresses.
  mapping(uint256 => address) private _subordinates;

  // Constructor that sets the name and symbol of the token.
  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  /// @dev Adds a new subordinate contract to the list of subordinates.
  /// @notice It should be called by the owner of the dominant token, but
  ///  we do not use specific ownership patterns here to leave the implementor
  ///  the option to use Ownable, AccessControl or other approaches.
  ///  The call to _canAddSubordinate  should take care of it,
  ///  as long as _canAddSubordinate is well implemented.
  /// @param subordinate The address of the subordinate contract to add.
  function addSubordinate(address subordinate) public virtual {
    _canAddSubordinate();
    if (ERC721(subordinate).supportsInterface(type(IERC721Subordinate).interfaceId) == false)
      revert NotASubordinate(subordinate);
    if (IERC721Subordinate(subordinate).dominantToken() != address(this)) revert NotOwnedByDominant(subordinate, address(this));
    _subordinates[_nextSubordinateId++] = subordinate;
  }

  /// @dev Checks for permissions to allow adding a subordinate
  /// @dev It must be implemented by the contract that extends ERC721Dominant.
  //   Example:
  //    function _canAddSubordinate() internal override onlyOwner {}
  function _canAddSubordinate() internal virtual;

  /// @dev Retrieves the subordinate contract address by its index.
  /// @param index The index of the subordinate contract to retrieve.
  function subordinateByIndex(uint256 index) external view virtual returns (address) {
    return _subordinates[index];
  }

  /// @dev Checks if the given contract address is a registered subordinate of this dominant token.
  /// @param subordinate_ The address of the subordinate contract to check.
  function isSubordinate(address subordinate_) public view virtual override returns (bool) {
    for (uint256 i = 0; i < _nextSubordinateId; i++) {
      if (_subordinates[i] == subordinate_) {
        return true;
      }
    }
    return false;
  }

  /// @dev Returns the total number of registered subordinates.
  function countSubordinates() public view virtual override returns (uint256) {
    return _nextSubordinateId;
  }

  /// @dev Supports checking for the IERC721Dominant interface in addition to the inherited ERC721 interfaces.
  /// @param interfaceId The interface identifier, as specified in ERC-165.
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
    return interfaceId == type(IERC721Dominant).interfaceId || super.supportsInterface(interfaceId);
  }

  /// @dev Handles the token transfer, emits the transfer event for subordinate tokens, and protects against reentrancy.
  /// @param from The address of the sender.
  /// @param to The address of the recipient.
  /// @param tokenId The ID of the token to transfer.
  /// @param batchSize The number of tokens to transfer.
  function _afterTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal virtual override(ERC721) nonReentrant {
    super._afterTokenTransfer(from, to, tokenId, batchSize);

    // Emit transfer event for each registered subordinate.
    for (uint256 i = 0; i < _nextSubordinateId; i++) {
      address subordinate = _subordinates[i];
      if (subordinate != address(0)) {
        IERC721Subordinate(subordinate).emitTransfer(from, to, tokenId);
      }
    }
  }
}
