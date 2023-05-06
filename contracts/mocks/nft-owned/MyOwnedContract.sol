// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../nft-owned/NFTOwned.sol";

contract MyOwnedContract is NFTOwned {
  error NotInitiated();

  mapping(uint256 => uint256) public amounts;
  mapping(uint256 => bool) public initiated;

  constructor(address owningToken_) NFTOwned(owningToken_) {}

  function init(uint256 tokenId) public onlyOwnerOf(tokenId) {
    initiated[tokenId] = true;
  }

  function addSomeAmount(uint256 tokenId, uint256 amount) public onlyOwnerOf(tokenId) {
    if (initiated[tokenId] == false) revert NotInitiated();
    amounts[tokenId] += amount;
  }

  // convenience function to get the interface id of the INFTOwned interface
  function getINFTOwnedInterfaceId() external pure returns (bytes4) {
    return type(INFTOwned).interfaceId;
  }
}
