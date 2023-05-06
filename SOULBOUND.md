# Simple Soulbound ERC721

A simple model for soulbound tokens and badges.

## The interfaces

### IERC721DefaultApprovable

```solidity
// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.17;

// Author: Francesco Sullo <francesco@sullo.co>

// erc165 interfaceId 0xbfdf8f79
interface IERC721DefaultApprovable {
  // Must be emitted when the contract is deployed.
  event DefaultApprovable(bool approvable);

  // Must be emitted any time the status changes.
  event Approvable(uint256 indexed tokenId, bool approvable);

  // Returns true if the token is approvable.
  // It should revert if the token does not exist.
  function approvable(uint256 tokenId) external view returns (bool);

  // A contract implementing this interface should not allow
  // the approval for all. So, any actor validating this interface
  // should assume that the tokens are not approvable for all.

  // An extension of this interface may include info about the
  // approval for all, but it should be considered as a separate
  // feature, not as a replacement of this interface.
}

```

### IERC6982

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

// erc165 interfaceId 0xb45a3c0e
interface IERC6982 {
  // Must be emitted one time, when the contract is deployed,
  // defining the default status of any token that will be minted
  event DefaultLocked(bool locked);

  // Must be emitted any time the status changes
  event Locked(uint256 indexed tokenId, bool locked);

  // Returns the status of the token.
  // If no special event occurred, it must return the default status.
  // It should revert if the token does not exist.
  function locked(uint256 tokenId) external view returns (bool);
}

```

## How to use it

Install the dependencies like

```
npm i @cruna/protocol
```

and use as

```solidity
// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@cruna/protocol/soulbound/Soulbound.sol";

contract MySoulbound is Soulbound {
  constructor() Soulbound("My Soulbound Token", "MST") {
    emit DefaultApprovable(false);
    emit DefaultLocked(true);
  }
}

```
