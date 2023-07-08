// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {IActors} from "./IActors.sol";

// erc165 interfaceId 0x8dca4bea
interface IProtectedERC721 {
  /**
   * @dev Emitted when a protector is proposed for an tokensOwner
   */
  event ProtectorProposed(address indexed tokensOwner, address indexed protector);

  /**
   * @dev Emitted when a protector resigns
   */
  event ProtectorResigned(address indexed tokensOwner, address indexed protector);

  /**
   * @dev Emitted when a protector is set for an tokensOwner
   */
  event ProtectorUpdated(address indexed tokensOwner, address indexed protector, bool status);

  /**
   * @dev Emitted when the number of protectors is locked or unlocked
   */
  event ProtectorsLocked(address indexed tokensOwner, bool locked);

  /**
   * @dev Emitted when the process to unlock the protectors is initiated by one protector
   */
  event ProtectorsUnlockInitiated(address indexed tokensOwner);

  /**
   * @dev Emitted when the process to update a protector starts
   */
  event ProtectorUpdateStarted(address indexed owner, address indexed protector, bool status);

  /**
   * @dev Emitted when the level of an allowed recipient is updated
   */
  event SafeRecipientUpdated(address indexed owner, address indexed recipient, IActors.Level level);

  /**
   * @dev Emitted when a beneficiary is updated
   */
  event BeneficiaryUpdated(address indexed owner, address indexed beneficiary, IActors.Status status);

  event Inherited(address indexed from, address indexed to, uint256 amount);

  error NotTheTokenOwner();
  error NotApprovable();
  error NotApprovableForAll();
  error NotTheContractDeployer();
  error TokenDoesNotExist();
  error SenderDoesNotOwnAnyToken();
  error ProtectorNotFound();
  error TokenAlreadyBeingTransferred();
  error AssociatedToAnotherOwner();
  error ProtectorAlreadySet();
  error ProtectorAlreadySetByYou();
  error NotAProtector();
  error NotOwnByRelatedOwner();
  error NotPermittedWhenProtectorsAreActive();
  error TokenIdTooBig();
  error PendingProtectorNotFound();
  error ResignationAlreadySubmitted();
  error UnsetNotStarted();
  error NotTheProtector();
  error NotATokensOwner();
  error ResignationNotSubmitted();
  error TooManyProtectors();
  error InvalidDuration();
  error NoActiveProtectors();
  error ProtectorsAlreadyLocked();
  error ProtectorsUnlockAlreadyStarted();
  error ProtectorsUnlockNotStarted();
  error ProtectorsNotLocked();
  error TimestampInvalidOrExpired();
  error WrongDataOrNotSignedByProtector();
  error SignatureAlreadyUsed();
  error OperatorAlreadyActive();
  error OperatorNotActive();
  error NotAFlexiVault();
  error VaultAlreadyAdded();
  error InvalidTokenUtils();
  error QuorumCannotBeZero();
  error QuorumCannotBeGreaterThanBeneficiaries();
  error BeneficiaryNotConfigured();
  error NotExpiredYet();
  error BeneficiaryAlreadyRequested();
  error InconsistentRecipient();
  error NotABeneficiary();
  error RequestAlreadyApproved();
  error NotTheRecipient();
  error Unauthorized();

  /**
  * @dev Return the protectors set for the tokensOwner
  * @notice It is not the specific tokenId that is protected, is all the tokens owned by
     tokensOwner_ that are protected. So, protectors are set for the tokensOwner, not for the specific token.
     It is this way to reduce gas consumption.
  * @param tokensOwner_ The tokensOwner address
  * @return The addresses of active protectors set for the tokensOwner
     The contract can implement intermediate statuses, like "pending" and "resigned", but the interface
     only requires a list of the "active" protectors
  */
  function protectorsFor(address tokensOwner_) external view returns (address[] memory);

  /**
   * @dev Check if an address is a protector for an tokensOwner
   * @param tokensOwner_ The tokensOwner address
   * @param protector_ The protector address
   * @return True if the protector is active for the tokensOwner.
   *   Pending protectors are not returned here
   */
  function isProtectorFor(address tokensOwner_, address protector_) external view returns (bool);

  /**
   * @dev Propose a protector for an tokensOwner
   * @notice The function MUST be executed by a user that owns at least one token
   * @param protector_ The protector address
   */
  function proposeProtector(address protector_) external;

  /**
   * @dev Confirm the protector role
   * @notice The function MUST be executed by the protector to confirm that they accept the role
   * @param tokensOwner_ The tokensOwner address
   * @param accepted_ True if the protector accepts the role
   */
  function acceptProposal(address tokensOwner_, bool accepted_) external;

  /**
  * @dev Unset a protector for an tokensOwner
  * @notice The function MUST be executed by an active protector to remove themself.
     The tokensOwner cannot remove a protector, because this would defy the reason for
     having a protector in the first place.
  * @param tokensOwner_ The tokenId's tokensOwner address
  */
  function resignAsProtectorFor(address tokensOwner_) external;

  /**
   * @dev Confirm the unset of a protector role
   * @notice The function MUST be executed by the tokensOwner to remove the protector
   * @param protector_ The protector address
   */
  function acceptResignation(address protector_) external;

  /**
  * @dev Locks the number of protectors for an tokensOwner
     If not locked, if the tokensOwner is hacked, the hacker could set a new protector
     and use the new protector to transfer all the tokens owned by tokensOwner.
  * @notice The function MUST be executed by the tokensOwner
  */
  function lockProtectors() external;

  /**
  * @dev Unlocks the number of protectors for an tokensOwner
  * @notice The function MUST be executed by an active protector and later
     approved by the tokensOwner
  * @param tokensOwner_ The tokensOwner address
  */
  function unlockProtectorsFor(address tokensOwner_) external;

  /**
  * @dev Approves the unlock of the number of protectors for an tokensOwner
  * @notice The function MUST be executed by the tokensOwner
  * @param approved True if the tokensOwner approves the unlock,
     false if the tokensOwner rejects the unlock
  */
  function approveUnlockProtectors(bool approved) external;

  /**
   * @dev Verifies if the transfer request is signed by a protector
   * @param tokenOwner_ The token owner
   * @param hash The hash of the transfer request
   * @param signature The signature of the transfer request
   * @return True if the transfer request is signed by a protector
   */
  function signedByProtector(address tokenOwner_, bytes32 hash, bytes memory signature) external view returns (bool);

  /**
   * @dev Transfers a token to a recipient usign a valid signed transferRequest
   * @notice The function MUST be executed by the owner
   * @param tokenId The token id
   * @param to The address of the recipient
   * @param timestamp The timestamp of the transfer request
   * @param signature The signature of the transfer request, signed by an active protector
   */
  function protectedTransfer(
    uint256 tokenId,
    address to,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;

  /**
   * @dev Checks if a signature has been used
   * @param signature The signature of the transfer request
   * @return True if the signature has been used
   */
  function isSignatureUsed(bytes calldata signature) external view returns (bool);

  /**
   * @dev Sets a signature as used
   * @param signature The signature of the transfer request
   */
  function setSignatureAsUsed(bytes calldata signature) external;

  /**
   * @dev Validates a timestamp and signature
   * @param tokenOwner_ The token owner
   * @param timestamp The timestamp of the transfer request
   * @param validFor The number of seconds the signature is valid for
   * @param hash The signed hash
   * @param signature The signature of the transfer request
   */
  function validateTimestampAndSignature(
    address tokenOwner_,
    uint256 timestamp,
    uint256 validFor,
    bytes32 hash,
    bytes calldata signature
  ) external;

  /**
   * @dev Invalidates a signature
   * @param tokenId The token id
   * @param hash The signed hash
   * @param signature The signature of the transfer request
   */
  function invalidateSignatureFor(uint256 tokenId, bytes32 hash, bytes calldata signature) external;

  // safe recipients

  function setSafeRecipient(address recipient, IActors.Level level) external;

  function setProtectedSafeRecipient(
    address recipient,
    IActors.Level level,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;

  function safeRecipientLevel(address tokenOwner_, address recipient) external view returns (IActors.Level);

  function getSafeRecipients(address tokenOwner_) external view returns (IActors.Actor[] memory);
}
