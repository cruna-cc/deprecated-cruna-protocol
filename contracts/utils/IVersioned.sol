// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

interface IVersioned {
  function version() external view returns (string memory);
}
