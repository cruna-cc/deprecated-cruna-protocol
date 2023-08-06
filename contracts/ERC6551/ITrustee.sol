// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITrustee {
  function isTrustee() external pure returns (bytes4);
}
