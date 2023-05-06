// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Authors: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "./INFTOwned.sol";

contract NFTOwned is INFTOwned {
  error OwningTokenNotAnNFT();

  IERC721 internal immutable _owningToken;

  constructor(address owningToken_) {
    _owningToken = IERC721(owningToken_);
    if (!_owningToken.supportsInterface(type(IERC721).interfaceId)) revert OwningTokenNotAnNFT();
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
