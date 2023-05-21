// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "../lockable/IERC6982.sol";
import "../lockable/IERC721DefaultApprovable.sol";

// erc165 interfaceId 0x8dca4bea
interface IProtectedERC721 {
  // @dev Emitted when a protector is proposed for an tokensOwner
  event ProtectorProposed(address indexed tokensOwner, address indexed protector);

  // @dev Emitted when a protector resigns
  event ProtectorResigned(address indexed tokensOwner, address indexed protector);

  // @dev Emitted when a protector is set for an tokensOwner
  event ProtectorUpdated(address indexed tokensOwner, address indexed protector, bool status);

  // @dev Emitted when a transfer is started by a protector
  event TransferStartedBy(address indexed protector, uint256 indexed tokenId, address indexed to, uint expiresAt);

  // @dev Emitted when a transfer is approved or canceled by the tokensOwner
  event TransferApproved(uint256 tokenId, address indexed to, bool approved);

  // @dev Emitted when the number of protectors is locked or unlocked
  event ProtectorsLocked(address indexed tokensOwner, bool locked);

  // @dev Emitted when the process to unlock the protectors is initiated by one protector
  event ProtectorsUnlockInitiated(address indexed tokensOwner);

  // There is no need for a TransferCompleted because a Transfer event will be emitted anyway by the ERC721 contract

  // @dev Return the protectors set for the tokensOwner
  // @notice It is not the specific tokenId that is protected, is all the tokens owned by
  //  tokensOwner_ that are protected. So, protectors are set for the tokensOwner, not for the specific token.
  //  It is this way to reduce gas consumption.
  // @param tokensOwner_ The tokensOwner address
  // @return The addresses of active protectors set for the tokensOwner
  //  The contract can implement intermediate statuses, like "pending" and "removable", but the interface
  //  only requires a list of the "active" protectors
  function protectorsFor(address tokensOwner_) external view returns (address[] memory);

  // @dev Check if an address is a protector for an tokensOwner
  // @param tokensOwner_ The tokensOwner address
  // @param protector_ The protector address
  // @return True if the protector is active for the tokensOwner.
  //  Pending protectors are not returned here
  function isProtectorFor(address tokensOwner_, address protector_) external view returns (bool);

  // @dev Propose a protector for an tokensOwner
  // @notice The function MUST be executed by a user that owns at least one token
  function proposeProtector(address protector_) external;

  // @dev Confirm the protector role
  // @notice The function MUST be executed by the protector to confirm that they accept the role
  // @param tokensOwner_ The tokensOwner address
  // @param accepted_ True if the protector accepts the role
  function acceptProposal(address tokensOwner_, bool accepted_) external;

  // @dev Unset a protector for an tokensOwner
  // @notice The function MUST be executed by an active protector to remove themself.
  //  The tokensOwner cannot remove a protector, because this would defy the reason for
  //  having a protector in the first place.
  // @param tokensOwner_ The tokenId's tokensOwner address
  function resignAsProtectorFor(address tokensOwner_) external;

  // @dev Confirm the unset of a protector role
  // @notice The function MUST be executed by the tokensOwner to remove the protector
  // @param protector_ The protector address
  function acceptResignation(address protector_) external;

  // @dev Initiates a transfer
  // @notice The function MUST be executed by a protector
  // @param tokenId_ The tokenId to transfer
  function initiateTransfer(uint256 tokenId, address to, uint256 validFor) external;

  // @dev Approves a transfer so that the token can be spend by an operator
  // @notice The function MUST be executed by the tokensOwner
  //  It should revert if the transfer in not initiated
  // @param tokenId_ The transferring tokenId
  // @param approved_ True if the transfer is approved
  //  false if the transfer is rejected
  // @return True if the transfer is approved, false if rejected or the initiation expired
  function approveTransfer(uint256 tokenId, bool approved_) external returns (bool);

  // @dev Approve a transfer and execute it
  // @notice The function MUST be executed by a protector
  //  It should revert if the transfer in not initiated
  // @param tokenId_ The transferring tokenId
  // @param completed_ True if the transfer is completed
  //  If false, the transfer is refused by the tokensOnwer
  function approveAndExecuteTransfer(uint256 tokenId, bool completed_) external;

  // @dev Locks the number of protectors for an tokensOwner
  //  If not locked, if the tokensOwner is hacked, the hacker could set a new protector
  //  and use the new protector to transfer all the tokens owned by tokensOwner.
  // @notice The function MUST be executed by the tokensOwner
  function lockProtectors() external;

  // @dev Unlocks the number of protectors for an tokensOwner
  // @notice The function MUST be executed by an active protector and later
  //  approved by the tokensOwner
  // @param tokensOwner_ The tokensOwner address
  function unlockProtectorsFor(address tokensOwner_) external;

  // @dev Approves the unlock of the number of protectors for an tokensOwner
  // @notice The function MUST be executed by the tokensOwner
  // @param approved_ True if the tokensOwner approves the unlock
  //  false if the tokensOwner rejects the unlock
  function approveUnlockProtectors(bool approved) external;
}
