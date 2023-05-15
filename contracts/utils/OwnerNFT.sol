// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// @dev The NFTs owning the bound account are all minted from this contract.
contract OwnerNFT is ERC721, Ownable {
  constructor() ERC721("OwnerNFT", "oNFT") {}

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }

  function ownerOf(uint256) public view override returns (address) {
    return owner();
  }
}
