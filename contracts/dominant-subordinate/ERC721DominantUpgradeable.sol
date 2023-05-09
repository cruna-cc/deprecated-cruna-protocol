// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./IERC721Dominant.sol";
import "./IERC721Subordinate.sol";

// @notice ERC721DominantUpgradeable is an abstract contract that represents a dominant NFT.
// It inherits from the standard ERC721 contract and adds functionality for managing subordinate NFTs.
abstract contract ERC721DominantUpgradeable is IERC721Dominant, Initializable, ERC721Upgradeable, ReentrancyGuardUpgradeable {
  error NotOwnedByDominant(address subordinate, address dominant);
  error NotASubordinate(address subordinate);

  /// @dev The ID for the next subordinate to be added.
  uint256 private _nextSubordinateId;

  /// @dev Mapping of subordinate IDs to their corresponding contract addresses.
  mapping(uint256 => address) private _subordinates;

  /// @dev Initializes the contract.
  /// @param name The name of the token.
  /// @param symbol The symbol of the token.
  // solhint-disable func-name-mixedcase
  function __ERC721Dominant_init(string memory name, string memory symbol) internal onlyInitializing {
    __ERC721_init(name, symbol);
    __ReentrancyGuard_init();
  }

  /// @dev Supports checking for the IERC721Dominant interface in addition to the inherited ERC721 interfaces.
  /// @param interfaceId The interface identifier, as specified in ERC-165.
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable) returns (bool) {
    return interfaceId == type(IERC721Dominant).interfaceId || super.supportsInterface(interfaceId);
  }

  /// @dev Adds a new subordinate contract to the list of subordinates.
  /// @param subordinate The address of the subordinate contract to add.
  function addSubordinate(address subordinate) public virtual {
    // this MUST be called by the owner of the dominant token
    // We do not use Ownable here to leave the implementor the option
    // to use AccessControl or other approaches. The following should
    // take care of it
    _canAddSubordinate();
    //
    if (ERC721Upgradeable(subordinate).supportsInterface(type(IERC721Subordinate).interfaceId) == false)
      revert NotASubordinate(subordinate);

    if (IERC721Subordinate(subordinate).dominantToken() != address(this)) revert NotOwnedByDominant(subordinate, address(this));

    _subordinates[_nextSubordinateId++] = subordinate;
  }

  /// @dev Checks for permissions to allow adding a subordinate
  /// @dev It must be implemented by the contract that extends ERC721Dominant.
  //   Example:
  //   function _canAddSubordinate() internal override onlyOwner {}
  function _canAddSubordinate() internal virtual;

  /// @dev Retrieves the subordinate contract address by its index.
  /// @param index The index of the subordinate contract to retrieve.
  function subordinateByIndex(uint256 index) public view virtual returns (address) {
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

  function countSubordinates() public view virtual override returns (uint256) {
    return _nextSubordinateId;
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal virtual override(ERC721Upgradeable) nonReentrant {
    super._afterTokenTransfer(from, to, tokenId, batchSize);
    for (uint256 i = 0; i < _nextSubordinateId; i++) {
      address subordinate = _subordinates[i];
      if (subordinate != address(0)) {
        IERC721Subordinate(subordinate).emitTransfer(from, to, tokenId);
      }
    }
  }

  uint256[50] private __gap;
}
