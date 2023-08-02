// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC6551Account} from "../../ERC6551/interfaces/IERC6551Account.sol";

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

  // testing a delegated call to transfer the NFT
  function transferFromBoundAccount(address from, address to, uint256 tokenId) public {
    IERC6551Account(payable(from)).execute(
      address(this),
      0,
      abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", from, to, tokenId),
      0
    );
  }
}
