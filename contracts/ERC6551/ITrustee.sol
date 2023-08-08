// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITrustee {
  function firstTokenId() external pure returns (uint);

  function lastTokenId() external pure returns (uint);

  function isTrustee() external pure returns (bytes4);

  function boundAccount(uint tokenId) external view returns (address);
}
