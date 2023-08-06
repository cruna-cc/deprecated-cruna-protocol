// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Author : Francesco Sullo < francesco@superpower.io>
// (c) Superpower Labs Inc.

// Version one manages just our first cluster
interface IVaultFactory {
  /**
   * @dev Emitted when a price is set
   * @param price the new price
   */
  event PriceSet(uint256 price);

  event StableCoinSet(address stableCoin, bool active);

  error NoZeroAddress();
  error NotAContract();
  error NotAVault();
  error InsufficientFunds();
  error UnsupportedStableCoin();
  error TransferFailed();
  error InvalidPrice();
  error InvalidArguments();

  /**
    * @dev Set the price
    * @param price the new price
       The price is expressed in points, 1 point = 0.01 USD
    */
  function setPrice(uint256 price) external;

  function getPrice(string memory promoCode) external view returns (uint256);

  function finalPrice(address stableCoin, string memory promoCode) external view returns (uint256);

  function setPromoCode(string memory promoCode, uint discount) external;

  /**
   * @dev Activate/deactivate a stable coin
   * @param stableCoin the payment token to use for the purchase
   * @param active true to activate, false to deactivate
   */
  function setStableCoin(address stableCoin, bool active) external;

  /**
   * @dev Allow people to buy vaults
   * @param stableCoin the payment token to use for the purchase
   * @param amount number to buy
   */
  function buyVaults(address stableCoin, uint256 amount, string memory promoCode) external;

  function buyVaultsBatch(address stableCoin, address[] memory tos, uint256[] memory amounts, string memory promoCode) external;

  /**
   * @dev Given a payment token, transfers amount or full balance from proceeds to an address
   * @param beneficiary address of the beneficiary
   * @param stableCoin the payment token to use for the transfer
   * @param amount number to transfer
   */
  function withdrawProceeds(address beneficiary, address stableCoin, uint256 amount) external;
}
