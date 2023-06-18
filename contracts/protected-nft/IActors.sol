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

  enum Role {
    PROTECTOR,
    OPERATOR,
    RECIPIENT
  }

  enum Level {
    NONE,
    LOW,
    MEDIUM,
    HIGH
  }

  /**
    * @dev Protectors and recipients are actors
    * @notice It is not the specific tokenId that is protected, is all the tokens owned by
      tokensOwner_ that are protected. So, protectors are set for the tokensOwner, not for the specific token.
      It is this way to reduce gas consumption.
    */
  struct Actor {
    address actor;
    Status status;
    Level level;
  }
}
