// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Authors: Francesco Sullo <francesco@sullo.co>

// An owned contract has no control on its own ownership.
// Whoever owns the owning token owns the owned contract.

// ERC165 interface id is 0x920c8b9e
// solhint-disable-next-line
/* is ERC165 */ interface INFTOwned {
  // Must be throw if the owning token is not an NFT
  error OwningTokenNotAnNFT();

  // Must be emitted a single time, at deployment.
  // If emitted more than one time, the contract should be
  // considered compromised and not used.
  event OwningTokenSet(address owningToken);

  // Returns the address of the owning token.
  function owningToken() external view returns (address);

  // Returns the address of the owner of a specific tokenId of the owning token.
  // Notice that this protocol makes sense only for contract that implements
  // some logic using an id corresponding to a tokenId of the owning token.
  function ownerOf(uint256 tokenId) external view returns (address);
}
