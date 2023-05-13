// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../bound-account/interfaces/IERC6551Account.sol";

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

  function transferFromBoundAccount(address from, address to, uint tokenId) public {
    IERC6551Account(payable(from)).executeCall(
      address(this),
      0,
      abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", from, to, tokenId)
    );
  }
}
