// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

interface IAirdroppableTransparentSafeBox {
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
  error InvalidAddress();
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
  error InvalidAccountProxy();
  error AccountAlreadyActive();
  error NoETH();
  error NotActivated();
  error AccountHasBeenEjected();
  error NotAPreviouslyEjectedAccount();
  error AccountAlreadyEjected();
  error ETHDepositFailed();

  enum TokenType {
    ERC20,
    ERC721,
    ERC1155,
    // some extra slots for future extensions
    ERCx0,
    ERCx1,
    ERCx2
  }

  struct TypeAndTimestamp {
    TokenType tokenType;
    uint32 timestamp;
  }

  struct ProtectorAndTimestamp {
    address protector;
    uint32 expiresAt;
  }

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

  function startWithdrawal(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    uint32 validFor,
    address beneficiary
  ) external;

  function completeWithdrawal(uint256 owningTokenId, address asset, uint256 id, uint256 amount, address beneficiary) external;

  function amountOf(
    uint256 owningTokenId,
    address[] memory asset,
    uint256[] memory id
  ) external view returns (uint256[] memory);
}
