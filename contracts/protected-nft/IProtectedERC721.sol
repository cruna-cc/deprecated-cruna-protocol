// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

// erc165 interfaceId 0x8dca4bea
interface IProtectedERC721 {
  /*
    @dev Emitted when a protector is proposed for an tokensOwner
  */
  event ProtectorProposed(address indexed tokensOwner, address indexed protector);

  /*
    @dev Emitted when a protector resigns
  */
  event ProtectorResigned(address indexed tokensOwner, address indexed protector);

  /*
    @dev Emitted when a protector is set for an tokensOwner
  */
  event ProtectorUpdated(address indexed tokensOwner, address indexed protector, bool status);

  /*
    @dev Emitted when the number of protectors is locked or unlocked
  */
  event ProtectorsLocked(address indexed tokensOwner, bool locked);

  /*
    @dev Emitted when the process to unlock the protectors is initiated by one protector
  */
  event ProtectorsUnlockInitiated(address indexed tokensOwner);

  /*
    @dev Emitted when an operator is set/unset for a tokenId
  */
  event OperatorUpdated(uint indexed tokenId, address indexed operator, bool status);

  /*
    @dev Return the protectors set for the tokensOwner
    @notice It is not the specific tokenId that is protected, is all the tokens owned by
     tokensOwner_ that are protected. So, protectors are set for the tokensOwner, not for the specific token.
     It is this way to reduce gas consumption.
    @param tokensOwner_ The tokensOwner address
    @return The addresses of active protectors set for the tokensOwner
     The contract can implement intermediate statuses, like "pending" and "removable", but the interface
     only requires a list of the "active" protectors
  */
  function protectorsFor(address tokensOwner_) external view returns (address[] memory);

  /*
    @dev Check if an address is a protector for an tokensOwner
    @param tokensOwner_ The tokensOwner address
    @param protector_ The protector address
    @return True if the protector is active for the tokensOwner.
     Pending protectors are not returned here
  */
  function isProtectorFor(address tokensOwner_, address protector_) external view returns (bool);

  /*
    @dev Propose a protector for an tokensOwner
    @notice The function MUST be executed by a user that owns at least one token
    @param protector_ The protector address
  */
  function proposeProtector(address protector_) external;

  /*
    @dev Confirm the protector role
    @notice The function MUST be executed by the protector to confirm that they accept the role
    @param tokensOwner_ The tokensOwner address
    @param accepted_ True if the protector accepts the role
  */
  function acceptProposal(address tokensOwner_, bool accepted_) external;

  /*
    @dev Unset a protector for an tokensOwner
    @notice The function MUST be executed by an active protector to remove themself.
     The tokensOwner cannot remove a protector, because this would defy the reason for
     having a protector in the first place.
    @param tokensOwner_ The tokenId's tokensOwner address
  */
  function resignAsProtectorFor(address tokensOwner_) external;

  /*
    @dev Confirm the unset of a protector role
    @notice The function MUST be executed by the tokensOwner to remove the protector
    @param protector_ The protector address
  */
  function acceptResignation(address protector_) external;

  /*
    @dev Locks the number of protectors for an tokensOwner
     If not locked, if the tokensOwner is hacked, the hacker could set a new protector
     and use the new protector to transfer all the tokens owned by tokensOwner.
    @notice The function MUST be executed by the tokensOwner
  */
  function lockProtectors() external;

  /*
    @dev Unlocks the number of protectors for an tokensOwner
    @notice The function MUST be executed by an active protector and later
     approved by the tokensOwner
    @param tokensOwner_ The tokensOwner address
  */
  function unlockProtectorsFor(address tokensOwner_) external;

  /*
    @dev Approves the unlock of the number of protectors for an tokensOwner
    @notice The function MUST be executed by the tokensOwner
    @param approved_ True if the tokensOwner approves the unlock,
     false if the tokensOwner rejects the unlock
  */
  function approveUnlockProtectors(bool approved) external;

  /*
    @dev Verifies if the transfer request is signed by a protector
    @param tokenId The token id
    @param hash The hash of the transfer request
    @param signature The signature of the transfer request
    @return True if the transfer request is signed by a protector
  */
  function signedByProtector(uint tokenId, bytes32 hash, bytes memory signature) external view returns (bool);

  /*
    @dev Returns the hash of a transfer request
    @param tokenId The token id
    @param to The address of the recipient
    @param timestamp The timestamp of the transfer request
    @return The hash of the transfer request
  */
  function hashTransferRequest(uint256 tokenId, address to, uint256 timestamp) external view returns (bytes32);

  /*
    @dev Transfers a token to a recipient usign a valid signed transferRequest
    @notice The function MUST be executed by the owner
    @param tokenId The token id
    @param to The address of the recipient
    @param timestamp The timestamp of the transfer request
    @param signature The signature of the transfer request, signed by an active protector
    @param invalidateSignatureAfterUse If true, the signature cannot be used anymore
  */
  function protectedTransfer(uint tokenId, address to, uint256 timestamp, bytes calldata signature) external;

  /*
    @dev Checks if a signature has been used
    @param hashedSignature The hash of the signature
    @return True if the signature has been used
  */
  function isSignatureUsed(bytes32 hashedSignature) external view returns (bool);

  /*
    @dev Sets a signature as used
    @param hashedSignature The hash of the signature
  */
  function setSignatureAsUsed(bytes32 hashedSignature) external;

  // operators

  /*
    @dev Checks if an operator is active for a token
     returning also its index in the array
    @param tokenId The token id
    @param operator The address of the operator
    @return (true, index) if the operator is active for the token
     or (false, 0) if the operator is not active for the token
  */
  function getOperatorForIndexIfExists(uint tokenId, address operator) external view returns (bool, uint);

  /*
    @dev Check if an address is an operator for a token
    @param tokenId The token id
    @param operator The address of the operator
    @return true if the operator is active for the token, false otherwise
  */
  function isOperatorFor(uint tokenId, address operator) external view returns (bool);

  /*
    @dev Sets/unsets an operator for a token
    @notice The function MUST be executed by the owner
    @param tokenId The token id
    @param operator The address of the operator
    @param active True if the operator is active for the token, false otherwise
  */
  function setOperatorFor(uint tokenId, address operator, bool active) external;

  /*
    @dev Checks if an address is an owner or operator for a token
    @param tokenId The token id
    @param ownerOrOperator The address of the owner or operator
    @return true if the address is an owner or operator for the token, false otherwise
  */
  function isOwnerOrOperator(uint tokenId, address ownerOrOperator) external view returns (bool);
}
