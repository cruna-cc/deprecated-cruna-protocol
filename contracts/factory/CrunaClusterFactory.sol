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
  mapping(address => uint256) public proceedsBalances;
  mapping(bytes32 => uint) private _promoCodes;

  function initialize(address vault_) public initializer {
    __UUPSUpgradableTemplate_init();
    if (!IERC165Upgradeable(vault_).supportsInterface(type(IProtectedERC721).interfaceId)) revert NotAVault();
    vault = CrunaVault(vault_);
  }

  // @notice The price is in points, so that 1 point = 0.01 USD
  function setPrice(uint256 price_) external override onlyOwner {
    // it is owner's responsibility to set a reasonable price
    price = price_;
    emit PriceSet(price);
  }

  function setStableCoin(address stableCoin, bool active) external override onlyOwner {
    if (active) {
      // this should revert if the stableCoin is not an ERC20
      if (ERC20(stableCoin).decimals() < 6) revert UnsupportedStableCoin();
      if (!stableCoins[stableCoin]) {
        stableCoins[stableCoin] = true;
        emit StableCoinSet(stableCoin, active);
      }
    } else if (stableCoins[stableCoin]) {
      delete stableCoins[stableCoin];
      emit StableCoinSet(stableCoin, active);
    }
  }

  function setPromoCode(string memory promoCode, uint discount) external override onlyOwner {
    bytes32 promoCodeHash = keccak256(abi.encodePacked(promoCode));
    if (discount > 0) {
      _promoCodes[promoCodeHash] = discount;
    } else if (_promoCodes[promoCodeHash] > 0) {
      delete _promoCodes[promoCodeHash];
    }
  }

  function finalPrice(address stableCoin, string memory promoCode) public view override returns (uint256) {
    return (getPrice(promoCode) * (10 ** ERC20(stableCoin).decimals())) / 100;
  }

  function getPrice(string memory promoCode) public view override returns (uint256) {
    uint _price = price;
    if (bytes(promoCode).length > 0) {
      bytes32 promoCodeHash = keccak256(abi.encodePacked(promoCode));
      if (_promoCodes[promoCodeHash] > 0) {
        _price -= (_price * _promoCodes[promoCodeHash]) / 100;
      }
    }
    return _price;
  }

  function buyVaults(address stableCoin, uint256 amount, string memory promoCode) external override {
    uint256 payment = finalPrice(stableCoin, promoCode) * amount;
    if (payment > ERC20(stableCoin).balanceOf(_msgSender())) revert InsufficientFunds();
    proceedsBalances[stableCoin] += payment;
    for (uint256 i = 0; i < amount; i++) {
      vault.safeMint(0, _msgSender());
    }
    if (!ERC20(stableCoin).transferFrom(_msgSender(), address(this), payment)) revert TransferFailed();
  }

  function buyVaultsBatch(
    address stableCoin,
    address[] memory tos,
    uint256[] memory amounts,
    string memory promoCode
  ) external override {
    if (tos.length != amounts.length) revert InvalidArguments();
    uint amount = 0;
    for (uint256 i = 0; i < tos.length; i++) {
      if (tos[i] == address(0)) {
        revert NoZeroAddress();
      }
      amount += amounts[i];
    }
    uint256 payment = finalPrice(stableCoin, promoCode) * amount;
    if (payment > ERC20(stableCoin).balanceOf(_msgSender())) revert InsufficientFunds();
    proceedsBalances[stableCoin] += payment;
    for (uint256 i = 0; i < tos.length; i++) {
      if (amounts[i] != 0) {
        for (uint256 j = 0; j < amounts[i]; j++) {
          vault.safeMint(0, tos[i]);
        }
      }
    }
    if (!ERC20(stableCoin).transferFrom(_msgSender(), address(this), payment)) revert TransferFailed();
  }

  function withdrawProceeds(address beneficiary, address stableCoin, uint256 amount) external override onlyOwner {
    if (amount == 0) {
      amount = proceedsBalances[stableCoin];
    }
    if (amount > proceedsBalances[stableCoin]) revert InsufficientFunds();
    proceedsBalances[stableCoin] -= amount;
    if (!ERC20(stableCoin).transfer(beneficiary, amount)) revert TransferFailed();
  }
}
