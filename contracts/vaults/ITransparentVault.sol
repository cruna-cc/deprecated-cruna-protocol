// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

interface ITransparentVault {
  event BoundAccountEjected(uint256 indexed owningTokenId);
  event EjectedBoundAccountReInjected(uint256 indexed owningTokenId);

  error ForbiddenWhenOwningTokenApprovedForSale();
  error InconsistentLengths();
  error InsufficientBalance();
  error InvalidAmount();
  error InvalidAsset();
  error NotAllowedWhenProtector();
  error NotTheProtector();
  error NotTheOwningTokenOwner();
  error TransferFailed();
  error InvalidRegistry();
  error InvalidAccount();
  error AccountAlreadyActive();
  error NoETH();
  error NotActivated();
  error AccountHasBeenEjected();
  error NotAPreviouslyEjectedAccount();
  error AccountAlreadyEjected();
  error ETHDepositFailed();
  error AlreadyInitiated();
  error NotTheOwningTokenOwnerOrOperatorFor();
  error TimestampInvalidOrExpired();
  error WrongDataOrNotSignedByProtector();
  error SignatureAlreadyUsed();
  error OwningTokenNotProtected();

  enum TokenType {
    ERC20,
    ERC721,
    ERC1155
  }

  function init(address registry, address payable proxy) external;

  // must return `this.isTransparentVault.selector;`
  function isTransparentVault() external pure returns (bytes4);

  function depositETH(uint256 owningTokenId) external payable;

  function depositERC721(uint256 owningTokenId, address asset, uint256 id) external;

  function depositERC20(uint256 owningTokenId, address asset, uint256 amount) external;

  function depositERC1155(uint256 owningTokenId, address asset, uint256 id, uint256 amount) external;

  function depositAssets(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external;

  function withdrawAsset(uint256 owningTokenId, address asset, uint256 id, uint256 amount, address beneficiary) external;

  function protectedWithdrawAsset(
    uint256 owningTokenId,
    address asset, // if address(0) we want to withdraw the native token, for example Ether
    uint256 id,
    uint256 amount,
    address beneficiary,
    uint256 timestamp,
    bytes calldata signature
  ) external;

  function hashWithdrawRequest(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary,
    uint256 timestamp
  ) external view returns (bytes32);

  function withdrawAssets(
    uint owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries
  ) external;

  function protectedWithdrawAssets(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries,
    uint256 timestamp,
    bytes calldata signature
  ) external;

  function hashWithdrawsRequest(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries,
    uint256 timestamp
  ) external view returns (bytes32);

  function amountOf(
    uint256 owningTokenId,
    address[] memory asset,
    uint256[] memory id
  ) external view returns (uint256[] memory);
}
