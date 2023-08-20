// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Authors: Francesco Sullo <francesco@sullo.co>

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {INFTOwned} from "./INFTOwned.sol";

contract NFTOwned is INFTOwned {
  error Unauthorized();

  IERC721 internal immutable _owningToken;

  modifier onlyOwnerOf(uint256 tokenId) {
    if (msg.sender != ownerOf(tokenId)) revert Unauthorized();
    _;
  }

  constructor(address owningToken_) {
    _owningToken = IERC721(owningToken_);
    if (!_owningToken.supportsInterface(type(IERC721).interfaceId)) revert OwningTokenNotAnNFT();
    emit OwningTokenSet(owningToken_);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
    return interfaceId == type(INFTOwned).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function owningToken() public view virtual override returns (address) {
    return address(_owningToken);
  }

  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
    return _owningToken.ownerOf(tokenId);
  }
}
