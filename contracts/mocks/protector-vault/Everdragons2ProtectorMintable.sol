// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "./Everdragons2Protector.sol";

contract Everdragons2ProtectorMintable is Everdragons2Protector {
  uint256 private _nextTokenId;

  // this is used for testing
  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }

  // this is used for simulations
  function safeMint2(address to) public onlyOwner {
    _safeMint(to, ++_nextTokenId);
  }
}
