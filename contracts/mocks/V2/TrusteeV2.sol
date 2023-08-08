// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Trustee, ITrustee} from "../../ERC6551/Trustee.sol";

contract TrusteeV2 is Trustee {
  constructor() Trustee() {}

  function name() public pure virtual override returns (string memory) {
    return "Cruna Trustee V2";
  }

  function symbol() public pure virtual override returns (string memory) {
    return "CRUNA_T2";
  }

  function version() external pure virtual override returns (string memory) {
    return "2.0.0";
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://meta.cruna.io/trustee/v2/";
  }

  function contractURI() public view virtual override returns (string memory) {
    return "https://meta.cruna.io/trustee/v2/info";
  }

  function isTrustee() external pure override returns (bytes4) {
    return ITrustee.isTrustee.selector;
  }

  function firstTokenId() public pure override returns (uint) {
    return 100001;
  }

  function lastTokenId() public pure override returns (uint) {
    return 200000;
  }
}
