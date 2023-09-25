// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

// @dev manages upgrade and cross-chain execution settings for accounts
contract AccountGuardian is Ownable2Step {
  // @dev mapping from cross-chain executor => is trusted
  mapping(address => bool) public isTrustedImplementation;

  event TrustedImplementationUpdated(address implementation, bool trusted);

  function setTrustedImplementation(address implementation, bool trusted) external onlyOwner {
    isTrustedImplementation[implementation] = trusted;
    emit TrustedImplementationUpdated(implementation, trusted);
  }

  function isAccountGuardian() external pure returns (bool) {
    return true;
  }
}
