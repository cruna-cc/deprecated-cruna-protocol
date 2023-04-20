// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.17;

// Author: Francesco Sullo <francesco@sullo.co>

interface ITransparentVault {
  event AllowAllUpdated(uint256 indexed protectorId, bool allow);
  event AllowListUpdated(uint256 indexed protectorId, address indexed account, bool allow);
  event AllowWithConfirmationUpdated(uint256 indexed protectorId, bool allow);
  event Deposit(uint256 indexed protectorId, address indexed asset, uint256 indexed id, uint256 amount);
  event DepositTransfer(
    uint256 indexed protectorId,
    address indexed asset,
    uint256 id,
    uint256 amount,
    uint256 indexed senderProtectorId
  );
  event DepositTransferStarted(
    uint256 indexed protectorId,
    address indexed asset,
    uint256 id,
    uint256 amount,
    uint256 indexed senderProtectorId
  );
  event UnconfirmedDeposit(uint256 indexed protectorId, address indexed asset, uint256 indexed id, uint256 amount);
  event WithdrawalStarted(
    uint256 indexed protectorId,
    address indexed beneficiary,
    address indexed asset,
    uint256 id,
    uint256 amount
  );
  event Withdrawal(uint256 indexed protectorId, address indexed beneficiary, address indexed asset, uint256 id, uint256 amount);

  error AssetAlreadyBeingTransferred();
  error AssetAlreadyBeingWithdrawn();
  error AssetNotFound();
  error AssetNotDeposited();
  error Expired();
  error ForbiddenWhenProtectorApprovedForSale();
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
  error NotAllowedWhenInitiator();
  error NotTheDepositor();
  error NotTheDepositorOrInsufficientBalance();
  error NotTheInitiator();
  error NotTheProtectorOwner();
  error TransferFailed();
  error UnconfirmedDepositNotFoundOrExpired();
  error UnconfirmedDepositNotExpiredYet();
  error UnsupportedTooLargeTokenId();
  error WithdrawalNotFound();

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

  struct InitiatorAndTimestamp {
    address initiator;
    uint32 expiresAt;
  }

  function configure(
    uint256 protectorId,
    bool allowAll_,
    bool allowWithConfirmation_,
    address[] memory allowList_,
    bool[] memory allowListStatus_
  ) external;

  function depositERC721(
    uint256 protectorId,
    address asset,
    uint256 id
  ) external;

  function depositERC20(
    uint256 protectorId,
    address asset,
    uint256 amount
  ) external;

  function depositERC1155(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external;

  function depositAssets(
    uint256 protectorId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external;

  function confirmDeposit(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    address sender
  ) external;

  function withdrawExpiredUnconfirmedDeposit(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external;

  // transfer asset to another protector
  function transferAsset(
    uint256 protectorId,
    uint256 recipientProtectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external;

  function startTransferAsset(
    uint256 protectorId,
    uint256 recipientProtectorId,
    address asset,
    uint256 id,
    uint256 amount,
    uint32 validFor
  ) external;

  function completeTransferAsset(
    uint256 protectorId,
    uint256 recipientProtectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external;

  function withdrawAsset(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary
  ) external;

  function startWithdrawal(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    uint32 validFor,
    address beneficiary
  ) external;

  function completeWithdrawal(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary
  ) external;

  function amountOf(
    uint256 protectorId,
    address[] memory asset,
    uint256[] memory id
  ) external view returns (uint256[] memory);
}
