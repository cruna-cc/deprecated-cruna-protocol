// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CrunaWallet, ICrunaWallet} from "../../vaults/CrunaWallet.sol";

contract CrunaWalletV2 is CrunaWallet {
  constructor() CrunaWallet() {}

  function name() public pure virtual override returns (string memory) {
    return "Cruna CrunaWallet V2";
  }

  function symbol() public pure virtual override returns (string memory) {
    return "CRUNA_T2";
  }

  function version() external pure virtual override returns (string memory) {
    return "2.0.0";
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://meta.cruna.io/wallet/v2/";
  }

  function contractURI() public view virtual override returns (string memory) {
    return "https://meta.cruna.io/wallet/v2/info";
  }

  function isCrunaWallet() external pure override returns (bytes4) {
    return ICrunaWallet.isCrunaWallet.selector;
  }

  function firstTokenId() public pure override returns (uint) {
    return 100001;
  }

  function lastTokenId() public pure override returns (uint) {
    return 200000;
  }
}
