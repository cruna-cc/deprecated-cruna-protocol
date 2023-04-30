// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Particle is ERC721, Ownable {
  string private _baseTokenURI;

  constructor(string memory tokenUri) ERC721("Particle", "PTC") {
    _baseTokenURI = tokenUri;
  }

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }
}
