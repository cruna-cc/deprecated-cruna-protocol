// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.17;

import "../implementations/Everdragons2/Everdragons2Protector.sol";
import "@ndujalabs/erc721subordinate/contracts/interfaces/IERC721DefaultApprovable.sol";

contract Everdragons2ProtectorV2 is Everdragons2Protector {
  function version() public pure override returns (string memory) {
    return "2.0.0";
  }

  function getId() external pure returns (bytes4) {
    return type(IProtectorBase).interfaceId;
  }
}
