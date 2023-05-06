// SPDX-License-Identifier: GPL3

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import "./INFTOwned.sol";

contract NFTOwnedUpgradeable is INFTOwned, Initializable {
  error OwningTokenNotAnNFT();

  IERC721Upgradeable internal _owningToken;

  // solhint-disable func-name-mixedcase
  function __NFTOwned_init(address owningToken_) internal onlyInitializing {
    _owningToken = IERC721Upgradeable(owningToken_);
    if (!_owningToken.supportsInterface(type(IERC721Upgradeable).interfaceId)) revert OwningTokenNotAnNFT();
  }

  function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
    return interfaceId == type(INFTOwned).interfaceId || interfaceId == type(IERC165Upgradeable).interfaceId;
  }

  function owningToken() public view virtual override returns (address) {
    return address(_owningToken);
  }

  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
    return _owningToken.ownerOf(tokenId);
  }

  uint256[50] private __gap;
}
