// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

interface IFlexiVault {
  /**
   * @dev It checks if the contract is a Transparent Vault
   * @return bytes4(keccak256('isFlexiVault()')) if the contract is a Transparent Vault
   */
  function isFlexiVault() external pure returns (bytes4);

  /**
   * @dev It returns the address of the account bound to the tokenId
   * @param owningTokenId The id of the owning token
   * @return The address of the account
   */
  function accountAddress(uint owningTokenId) external view returns (address);

  /**
   * @dev It allows to set the registry and the account proxy
   * @param registry The address of the registry
   * @param boundAccount The address of the account proxy
   * @param boundAccountUpgradeable The address of the upgradeable account proxy
   */
  function init(address registry, address payable boundAccount, address payable boundAccountUpgradeable) external;

  //  /**
  //   * @dev Deposits Ether in the bound account
  //   * @param owningTokenId The id of the owning token
  //   */
  //  function depositETH(uint256 owningTokenId) external payable;

  //  /**
  //   * @dev Deposits ERC721 in the bound account
  //   * @param owningTokenId The id of the owning token
  //   * @param asset The address of the ERC721 contract
  //   * @param id The id of the ERC721 token
  //   */
  //  function depositERC721(uint256 owningTokenId, address asset, uint256 id) external;

  //  /**
  //   * @dev Deposits ERC20 in the bound account
  //   * @param owningTokenId The id of the owning token
  //   * @param asset The address of the ERC20 contract
  //   * @param amount The amount of the ERC20 token
  //   */
  //  function depositERC20(uint256 owningTokenId, address asset, uint256 amount) external;

  //  /**
  //   * @dev Deposits ERC1155 in the bound account
  //   * @param owningTokenId The id of the owning token
  //   * @param asset The address of the ERC1155 contract
  //   * @param id The id of the ERC1155 token
  //   * @param amount The amount of the ERC1155 token
  //   */
  //  function depositERC1155(uint256 owningTokenId, address asset, uint256 id, uint256 amount) external;

  /**
   * @dev Deposits multiple assets in the bound account
   * @param owningTokenId The id of the owning token
   * @param assets The addresses of the assets
   * @param ids The ids of the assets tokens
      If the asset is an ERC20, the id is 0
   * @param amounts The amounts of the assets tokens
      If the asset is an ERC721, the amount is 1
   */
  function depositAssets(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external payable;

  //  /**
  //   * @dev Withdraws an asset from the bound account
  //   * @param owningTokenId The id of the owning token
  //   * @param asset The address of the asset
  //      If the asset is the native token, for example Ether, the address is address(0)
  //   * @param id The id of the asset token
  //      If the asset is an ERC20, the id is 0
  //   * @param amount The amount of the asset token
  //      If the asset is an ERC721, the amount is 1
  //   * @param beneficiary The address of the beneficiary
  //   */
  //  function withdrawAsset(uint256 owningTokenId, address asset, uint256 id, uint256 amount, address beneficiary) external;

  //  /**
  //   * @dev Withdraws an asset from the bound account when a protector is active
  //   * @param owningTokenId The id of the owning token
  //   * @param asset The address of the asset
  //   * @param id The id of the asset token
  //   * @param amount The amount of the asset token
  //   * @param beneficiary The address of the beneficiary
  //   * @param timestamp The timestamp of the request
  //   * @param validFor The time the request is valid for
  //   * @param signature The signature of the protector
  //   */
  //  function protectedWithdrawAsset(
  //    uint256 owningTokenId,
  //    address asset, // if address(0) we want to withdraw the native token, for example Ether
  //    uint256 id,
  //    uint256 amount,
  //    address beneficiary,
  //    uint256 timestamp,
  //    uint validFor,
  //    bytes calldata signature
  //  ) external;

  /**
   * @dev Withdraws multiple assets from the bound account
   * @param owningTokenId The id of the owning token
   * @param assets The addresses of the assets
      If the asset is the native token, for example Ether, the address is address(0)
   * @param ids The ids of the assets tokens
      If the asset is an ERC20, the id is 0
   * @param amounts The amounts of the assets tokens
      If the asset is an ERC721, the amount is 1
   * @param beneficiaries The addresses of the beneficiaries
   */
  function withdrawAssets(
    uint owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries
  ) external;

  /**
   * @dev Withdraws multiple assets from the bound account when a protector is active
   * @param owningTokenId The id of the owning token
   * @param assets The addresses of the assets
   * @param ids The ids of the assets tokens
   * @param amounts The amounts of the assets tokens
   * @param beneficiaries The addresses of the beneficiaries
   * @param timestamp The timestamp of the request
   * @param validFor The time the request is valid for
   * @param signature The signature of the protector
   */
  function protectedWithdrawAssets(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries,
    uint256 timestamp,
    uint validFor,
    bytes calldata signature
  ) external;

  /**
   * @dev It returns the amount of a set of assets in the bound account
   * @param owningTokenId The id of the owning token
   * @param assets The addresses of the assets
   * @param ids The ids of the assets token
   * @return amounts The amount of the asset token
   * @notice External services who need to see what a transparent vaults contains can call
      the Cruna Web API to get the list of assets owned by a owningToken. Then, they can call
      this view to validate the results.
   */
  function amountOf(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids
  ) external view returns (uint256[] memory);

  /**
   * @dev Ejects a bound account
   * @param owningTokenId The id of the owning token
   */
  function ejectAccount(uint256 owningTokenId) external;

  /**
   * @dev Ejects a bound account when a protector is active
   * @param owningTokenId The id of the owning token
   * @param timestamp The timestamp of the request
   * @param validFor The time the request is valid for
   * @param signature The signature of the protector
   */
  function protectedEjectAccount(uint256 owningTokenId, uint256 timestamp, uint validFor, bytes calldata signature) external;

  /**
   * @dev Reinjects an ejected account
   * @param owningTokenId The id of the owning token
   */
  function reInjectEjectedAccount(uint256 owningTokenId) external;
}
