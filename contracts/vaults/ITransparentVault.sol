// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

interface ITransparentVault {
  event AllowAllUpdated(uint256 indexed owningTokenId, bool allow);
  event AllowListUpdated(uint256 indexed owningTokenId, address indexed account, bool allow);
  event AllowWithConfirmationUpdated(uint256 indexed owningTokenId, bool allow);
  event Deposit(uint256 indexed owningTokenId, address indexed asset, uint256 indexed id, uint256 amount);
  event DepositTransfer(
    uint256 indexed owningTokenId,
    address indexed asset,
    uint256 id,
    uint256 amount,
    uint256 indexed senderOwningTokenId
  );
  event DepositTransferStarted(
    uint256 indexed owningTokenId,
    address indexed asset,
    uint256 id,
    uint256 amount,
    uint256 indexed senderOwningTokenId
  );
  event UnconfirmedDeposit(uint256 indexed owningTokenId, address indexed asset, uint256 indexed id, uint256 amount);
  event WithdrawalStarted(
    uint256 indexed owningTokenId,
    address indexed beneficiary,
    address indexed asset,
    uint256 id,
    uint256 amount
  );
  event Withdrawal(
    uint256 indexed owningTokenId,
    address indexed beneficiary,
    address indexed asset,
    uint256 id,
    uint256 amount
  );

  event BoundAccountEjected(uint256 indexed owningTokenId);
  event EjectedBoundAccountReInjected(uint256 indexed owningTokenId);

  error AssetAlreadyBeingTransferred();
  error AssetAlreadyBeingWithdrawn();
  error AssetNotFound();
  error AssetNotDeposited();
  error Expired();
  error ForbiddenWhenOwningTokenApprovedForSale();
  error InconsistentLengths();
  error InsufficientBalance();
  error InvalidAmount();
  error InvalidAsset();
  error InvalidId();
  error InvalidRecipient();
  error InvalidTransfer();
  error InvalidWithdrawal();
  error NotAllowed();
  error NotAllowedWhenProtector();
  error NotTheDepositor();
  error NotTheDepositorOrInsufficientBalance();
  error NotTheProtector();
  error NotTheOwningTokenOwner();
  error TransferFailed();
  error UnconfirmedDepositNotFoundOrExpired();
  error UnconfirmedDepositNotExpiredYet();
  error UnsupportedTooLargeTokenId();
  error WithdrawalNotFound();
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
    uint randomSalt,
    bytes calldata signature,
    bool invalidateSignatureAfterUse
  ) external;

  function withdrawAsset(uint256 owningTokenId, address asset, uint256 id, uint256 amount, uint recipientTokenId) external;

  function protectedWithdrawAsset(
    uint256 owningTokenId,
    address asset, // if address(0) we want to withdraw the native token, for example Ether
    uint256 id,
    uint256 amount,
    uint recipientTokenId,
    uint256 timestamp,
    uint randomSalt,
    bytes calldata signature,
    bool invalidateSignatureAfterUse
  ) external;

  function hashWithdrawRequest(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary,
    uint256 timestamp,
    uint randomSalt
  ) external view returns (bytes32);

  function amountOf(
    uint256 owningTokenId,
    address[] memory asset,
    uint256[] memory id
  ) external view returns (uint256[] memory);
}
