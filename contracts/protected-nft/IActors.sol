// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

interface IActors {
  error NoZeroAddress();
  error InvalidRole();
  error ActorNotFound(Role role);
  error ActorAlreadyAdded();

  enum Status {
    UNSET,
    PENDING,
    ACTIVE,
    RESIGNED
  }

  /**
    * @dev Protectors, beneficiaries and recipients are actors
       with well separated roles
    */
  enum Role {
    PROTECTOR,
    BENEFICIARY,
    RECIPIENT
  }

  /**
    * @dev Recipients can have different levels of protection
       a recipient level LOW or MEDIUM can move assets inside the vault skipping the protector
       a recipient level HIGH can receive the CrunaVault skipping the protector
    */
  enum Level {
    NONE,
    LOW,
    MEDIUM,
    HIGH
  }

  /**
    * @dev Protectors, beneficiaries and recipients are actors
    * @notice Actors are set for the tokensOwner, not for the specific token,
       to reduce gas consumption.
    */
  struct Actor {
    address actor;
    Status status;
    Level level;
  }
}
