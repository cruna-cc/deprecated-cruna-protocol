// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "../../soulbound/Soulbound.sol";

contract MySoulbound is Soulbound {
  constructor() Soulbound("My Soulbound Token", "MST") {
    emit DefaultApprovable(false);
    emit DefaultLocked(true);
  }
}
