// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERCxyz {
  function ownerOfToken(address tokenAddress, uint256 tokenId) external view returns (address);
}
