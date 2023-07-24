// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Author : Francesco Sullo < francesco@superpower.io>
// (c) Superpower Labs Inc.

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import {CrunaVault} from "../implementation/CrunaVault.sol";
import {UUPSUpgradableTemplate} from "../utils/UUPSUpgradableTemplate.sol";
import {IProtectedERC721} from "../protected-nft/IProtectedERC721.sol";

import {ICrunaClusterFactory} from "./ICrunaClusterFactory.sol";

//import {console} from "hardhat/console.sol";

contract CrunaClusterFactory is ICrunaClusterFactory, UUPSUpgradableTemplate {
  CrunaVault public vault;
  uint256 public price;

  mapping(address => bool) public stableCoins;

  // TODO this variable can be remove when going to production. I am leaving it here now so. I can upgrade the contract during development
  mapping(address => uint256) public proceedsBalances;

  address[] private _stableCoins;

  function initialize(address vault_) public initializer {
    __UUPSUpgradableTemplate_init();
    if (!IERC165Upgradeable(vault_).supportsInterface(type(IProtectedERC721).interfaceId)) revert NotAVault();
    vault = CrunaVault(vault_);
  }

  // @notice The price is in points, so that 1 point = 0.01 USD
  function setPrice(uint256 price_) external onlyOwner {
    // it is owner's responsibility to set a reasonable price
    price = price_;
    emit PriceSet(price);
  }

  function setStableCoin(address stableCoin, bool active) external onlyOwner {
    if (active) {
      // this should revert if the stableCoin is not an ERC20
      if (ERC20(stableCoin).decimals() < 6) revert UnsupportedStableCoin();
      if (!stableCoins[stableCoin]) {
        stableCoins[stableCoin] = true;
        _stableCoins.push(stableCoin);
        emit StableCoinSet(stableCoin, active);
      }
    } else if (stableCoins[stableCoin]) {
      delete stableCoins[stableCoin];
      for (uint256 i = 0; i < _stableCoins.length; i++) {
        if (_stableCoins[i] == stableCoin) {
          _stableCoins[i] = _stableCoins[_stableCoins.length - 1];
          _stableCoins.pop();
          break;
        }
      }
      emit StableCoinSet(stableCoin, active);
    }
  }

  function finalPrice(address stableCoin) public view returns (uint256) {
    if (!stableCoins[stableCoin]) revert UnsupportedStableCoin();
    return (price * (10 ** ERC20(stableCoin).decimals())) / 100;
  }

  function buyVaults(address stableCoin, uint256 amount) external {
    uint256 payment = finalPrice(stableCoin) * amount;
    if (payment > ERC20(stableCoin).balanceOf(_msgSender())) revert InsufficientFunds();
    proceedsBalances[stableCoin] += payment;
    if (!ERC20(stableCoin).transferFrom(_msgSender(), address(this), payment)) revert TransferFailed();
    for (uint256 i = 0; i < amount; i++) {
      vault.safeMint(0, _msgSender());
    }
  }

  function withdrawProceeds(address beneficiary, address stableCoin, uint256 amount) public onlyOwner {
    if (amount == 0) {
      amount = proceedsBalances[stableCoin];
    }
    if (amount > proceedsBalances[stableCoin]) revert InsufficientFunds();
    proceedsBalances[stableCoin] -= amount;
    if (!ERC20(stableCoin).transfer(beneficiary, amount)) revert TransferFailed();
  }

  function getStableCoins() external view returns (address[] memory) {
    return _stableCoins;
  }
}
