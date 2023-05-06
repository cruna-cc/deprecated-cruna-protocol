// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyOwningToken is Ownable, ERC721 {
  constructor() ERC721("MyToken", "MTK") {}

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }
}
