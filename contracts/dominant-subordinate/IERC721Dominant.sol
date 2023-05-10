// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Authors: Francesco Sullo <francesco@sullo.co>

/// @dev A subordinate token can be associated to any ERC721 token.
///  However, if it is necessary that the subordinate token is visible on services
///  like marketplaces, the dominant token must propagate any Transfer
///  event to the subordinate

// ERC165 interface id is 0x48b041fd
interface IERC721Dominant {
  /// @dev Returns the address of the dominant token.
  /// @param index the index of the subordinate token
  function subordinateByIndex(uint256 index) external view returns (address);

  /// @dev Returns the index of the subordinate token.
  /// @param subordinate_ the address of the subordinate token
  function isSubordinate(address subordinate_) external view returns (bool);

  /// @dev Returns the index of the subordinate token.
  function countSubordinates() external view returns (uint256);
}
