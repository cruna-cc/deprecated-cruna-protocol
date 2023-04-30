// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

// interfaceId 0x855f1e29
interface IProtectorBase {
  function isProtector() external pure returns (bool);
}
