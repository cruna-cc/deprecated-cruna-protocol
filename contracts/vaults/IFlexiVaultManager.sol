// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

interface IFlexiVaultManager {
  enum TokenType {
    ETH,
    ERC20,
    ERC721,
    ERC1155
  }

  enum AccountStatus {
    INACTIVE,
    ACTIVE
  }

  /**
   * @dev It checks if the contract is a Transparent Vault
   * @return bytes4(keccak256('isFlexiVaultManager()')) if the contract is a Transparent Vault
   */
  function isFlexiVaultManager() external pure returns (bytes4);

  /**
   * @dev It returns the address of the account bound to the tokenId
   * @param owningTokenId The id of the owning token
   * @return The address of the account
   */
  function accountAddress(uint256 owningTokenId) external view returns (address);

  /**
   * @dev It allows to set the registry and the account proxy
   * @param registry The address of the registry
   * @param boundAccount The address of the account proxy
   * @param boundAccountUpgradeable The address of the upgradeable account proxy
   */
  function init(address registry, address payable boundAccount, address payable boundAccountUpgradeable) external;

  /**
   * @dev Deposits multiple assets in the bound account
   * @param owningTokenId The id of the owning token
   * @param tokenTypes The types of the assets tokens
   * @param assets The addresses of the assets
   * @param ids The ids of the assets tokens
      If the asset is an ERC20, the id is 0
   * @param amounts The amounts of the assets tokens
      If the asset is an ERC721, the amount is 1
   */
  function depositAssets(
    uint256 owningTokenId,
    TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external payable;

  /**
   * @dev Withdraws multiple assets from the bound account
   * @param owningTokenId The id of the owning token
   * @param assets The addresses of the assets
      If the asset is the native token, for example Ether, the address is address(0)
   * @param ids The ids of the assets tokens
      If the asset is an ERC20, the id is 0
   * @param amounts The amounts of the assets tokens
      If the asset is an ERC721, the amount is 1
   * @param recipients The addresses of the recipients
   * @param timestamp The timestamp of the request
   * @param validFor The time the request is valid for
   * @param signature The signature of the request
   */
  function withdrawAssets(
    uint256 owningTokenId,
    TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory recipients,
    uint256 timestamp,
    uint256 validFor,
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
   * @param timestamp The timestamp of the request
   * @param validFor The time the request is valid for
   * @param signature The signature of the request
   */
  function ejectAccount(uint256 owningTokenId, uint256 timestamp, uint256 validFor, bytes calldata signature) external;

  /**
   * @dev Reinjects an ejected account
   * @param owningTokenId The id of the owning token
   */
  function reInjectEjectedAccount(uint256 owningTokenId) external;

  /**
   * @dev It fixes an account directly injected
      Some user may transfer the ownership of a Trustee.sol to the FlexiVaultManager.sol without calling the reInjectEjectedAccount function.
      If that happens, the FlexiVaultManager.sol is unable to manage the Trustee.sol, and the bound account would be lost.
   * @param owningTokenId The id of the owning token
   */
  function fixDirectlyInjectedAccount(uint256 owningTokenId) external;

  /**
* @dev Checks if an operator is active for a token
     returning also its index in the array
  * @param tokenId The token id
  * @param operator The address of the operator
  * @return (true, index) if the operator is active for the token
     or (false, 0) if the operator is not active for the token
  */
  function getOperatorForIndexIfExists(uint256 tokenId, address operator) external view returns (bool, uint256);

  /**
   * @dev Check if an address is an operator for a token
   * @param tokenId The token id
   * @param operator The address of the operator
   * @return true if the operator is active for the token, false otherwise
   */
  function isOperatorFor(uint256 tokenId, address operator) external view returns (bool);

  /**
   * @dev Sets/unsets an operator for a token
   * @notice The function MUST be executed by the owner
   * @param tokenId The token id
   * @param operator The address of the operator
   * @param active True if the operator is active for the token, false otherwise
   */
  function setOperatorFor(uint256 tokenId, address operator, bool active) external;

  /**
   * @dev Delete the operators associated to an account
      It must be called by the FlexiVault only.
   * @param tokenId The token id
   */
  function removeOperatorsFor(uint256 tokenId) external;
}
