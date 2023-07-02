// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "./IActors.sol";

//import "hardhat/console.sol";

contract Actors is IActors {
  mapping(Role => mapping(address => Actor[])) private _actors;
  Actor private _emptyActor = Actor(address(0), Status.UNSET, Level.NONE);

  function _getActors(address owner_, Role role) internal view returns (Actor[] memory) {
    return _actors[role][owner_];
  }

  function _getActor(address owner_, address actor_, Role role) internal view returns (uint, Actor storage) {
    Actor[] storage actors = _actors[role][owner_];
    for (uint i = 0; i < actors.length; i++) {
      if (actors[i].actor == actor_) {
        return (i, actors[i]);
      }
    }
    // Caller must check _emptyActor.status
    // If not, must call _findActor, which reverts if actor not found
    return (0, _emptyActor);
  }

  // similar to getActor, but reverts if actor not found
  function _findActor(address owner_, address actor_, Role role) internal view returns (uint, Actor storage) {
    (uint i, Actor storage actor) = _getActor(owner_, actor_, role);
    if (actor.status == Status.UNSET) {
      revert ActorNotFound(role);
    }
    return (i, actor);
  }

  function _actorStatus(address owner_, address actor_, Role role) internal view returns (Status) {
    (, Actor storage actor) = _getActor(owner_, actor_, role);
    return actor.status;
  }

  function _actorLength(address owner_, Role role) internal view returns (uint) {
    return _actors[role][owner_].length;
  }

  function _actorLevel(address owner_, address actor_, Role role) internal view returns (Level) {
    (, Actor storage actor) = _findActor(owner_, actor_, role);
    return actor.level;
  }

  function _isActiveActor(address owner_, address actor_, Role role) internal view returns (bool) {
    Status status = _actorStatus(owner_, actor_, role);
    return status > Status.PENDING;
  }

  function _listActiveActors(address owner_, Role role) internal view returns (address[] memory) {
    uint count = role == Role.PROTECTOR ? _countActiveActorsByRole(owner_, role) : _actorLength(owner_, role);
    address[] memory actors = new address[](count);
    uint j = 0;
    for (uint i = 0; i < _actors[role][owner_].length; i++) {
      if (_actors[role][owner_][i].status > Status.PENDING) {
        actors[j] = _actors[role][owner_][i].actor;
        j++;
      }
    }
    return actors;
  }

  function _countActiveActorsByRole(address owner_, Role role) internal view returns (uint) {
    uint count = 0;
    for (uint i = 0; i < _actors[role][owner_].length; i++) {
      if (_actors[role][owner_][i].status > Status.PENDING) {
        count++;
      }
    }
    return count;
  }

  function _updateStatus(address owner_, uint i, Role role, Status status_) internal {
    _actors[role][owner_][i].status = status_;
  }

  function _updateLevel(address owner_, uint i, Role role, Level level_) internal {
    _actors[role][owner_][i].level = level_;
  }

  function _removeActor(address owner_, address actor_, Role role) internal {
    (uint i, ) = _findActor(owner_, actor_, role);
    _removeActorByIndex(owner_, i, role);
  }

  function _removeActorByIndex(address owner_, uint i, Role role) internal {
    Actor[] storage actors = _actors[role][owner_];
    if (i < actors.length - 1) {
      actors[i] = actors[actors.length - 1];
    }
    actors.pop();
  }

  function _addActor(address owner_, address actor_, Role role, Status status_, Level level) internal {
    if (actor_ == address(0)) revert NoZeroAddress();
    Status status = _actorStatus(owner_, actor_, role);
    if (status != Status.UNSET) revert ActorAlreadyAdded();
    _actors[role][owner_].push(Actor(actor_, status_, level));
  }
}
