// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Author : Francesco Sullo < francesco@superpower.io>
// (c) Superpower Labs Inc.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import "../implementation/CrunaVault.sol";
import "../utils/UUPSUpgradableTemplate.sol";
import "../protected-nft/IProtectedERC721.sol";

import "./ICrunaClusterFactory.sol";

import "hardhat/console.sol";

contract CrunaClusterFactory is ICrunaClusterFactory, UUPSUpgradableTemplate {
  CrunaVault public vault;
  uint public price;
  mapping(address => bool) public stableCoins;
  mapping(address => uint) public proceedsBalances;

  function initialize(address vault_) public initializer {
    __UUPSUpgradableTemplate_init();
    if (!IERC165Upgradeable(vault_).supportsInterface(type(IProtectedERC721).interfaceId)) revert NotAVault();
    vault = CrunaVault(vault_);
  }

  // @notice The price is in points, so that 1 point = 0.01 USD
  function setPrice(uint price_) external onlyOwner {
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
        emit StableCoinSet(stableCoin, active);
      }
    } else if (stableCoins[stableCoin]) {
      delete stableCoins[stableCoin];
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
    for (uint i = 0; i < amount; i++) {
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
}
