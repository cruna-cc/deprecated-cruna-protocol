// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "./Everdragons2Protector.sol";

contract Everdragons2ProtectorV2 is Everdragons2Protector {
  function version() public pure override returns (string memory) {
    return "2.0.0";
  }

  function getId() external pure returns (bytes4) {
    return type(IProtectorBase).interfaceId;
  }
}
