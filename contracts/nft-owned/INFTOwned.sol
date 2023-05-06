// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Authors: Francesco Sullo <francesco@sullo.co>

// An owned contract has no control on its own ownership.
// Whoever owns the owning token owns the owned contract.
// ERC165 interface id is 0x920c8b9e

/* is ERC165 */
interface INFTOwned {
  // Returns the address of the owning token.
  function owningToken() external view returns (address);

  // Returns the address of the owner of a specific tokenId of the owning token.
  // Notice that this protocol makes sense only for contract that implements
  // some logic using an id corresponding to a tokenId of the owning token.
  function ownerOf(uint256 tokenId) external view returns (address);
}
