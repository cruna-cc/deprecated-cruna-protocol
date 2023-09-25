// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract MyOwningToken is Ownable2Step, ERC721 {
  constructor() ERC721("MyToken", "MTK") {}

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }
}
