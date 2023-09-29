// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// from https://github.com/erc6551/reference

/// @author: manifold.xyz

import {IERC777Recipient} from "@openzeppelin/contracts/token/ERC777/ERC777.sol";

import {ERC6551AccountUpgradeable} from "erc6551/examples/upgradeable/ERC6551AccountUpgradeable.sol";
import {AccountGuardian} from "./AccountGuardian.sol";

//import {console} from "hardhat/console.sol";

contract CrunaAccount is ERC6551AccountUpgradeable, IERC777Recipient {
  address public guardian;

  function supportsInterface(bytes4 interfaceId) public pure override(ERC6551AccountUpgradeable) returns (bool) {
    return interfaceId == type(IERC777Recipient).interfaceId || super.supportsInterface(interfaceId);
  }

  // solhint-disable-next-line no-empty-blocks
  function tokensReceived(address, address, address, uint, bytes calldata, bytes calldata) public virtual override {}

  constructor(address guardian_) {
    require(AccountGuardian(guardian_).isAccountGuardian(), "Not a guardian");
    guardian = guardian_;
  }
}
