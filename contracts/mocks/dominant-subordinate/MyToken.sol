// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../../dominant-subordinate/ERC721Dominant.sol";

contract MyToken is ERC721Dominant, Ownable {
  constructor() ERC721Dominant("MyToken", "MTK") {}

  function _baseURI() internal pure override returns (string memory) {
    return "https://img.everdragons2.com/e2gt/";
  }

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }

  function getInterfacesIds() public pure returns (bytes4, bytes4) {
    return (type(IERC721Dominant).interfaceId, type(IERC721Subordinate).interfaceId);
  }

  function _canAddSubordinate() internal override onlyOwner {}
}
