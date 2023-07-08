// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {IActors} from "./IActors.sol";

interface ProtectedERC721Events {
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
}
