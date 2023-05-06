# Dominant-Subordinate Protocol

### This was previously in @ndujaLabs/ERC721Subordinate

A protocol to subordinate ERC721 contracts to a dominant contract so that the subordinate follows the ownership of the dominant, which can be even be an ERC721 contract that does not have any additional features.

## Why

In 2021, when we started Everdragons2, we had in mind of using the head of the dragons for a PFP token based on the Everdragons2 that you own. Here an example of a full dragon and just the head.

![Dragon](./assets/Soolhoth.png)

![DragonPFP](./assets/Soolhoth_PFP.png)

The question was, _Should we allow people to transfer the PFP separately from the primary NFT?_ It didn't make much sense. At the same time, how to avoid that?

ERC721Subordinate introduces a subordinate token that are owned by whoever owns the dominant token. In consequence of this, the subordinate token cannot be approved or transferred separately from the dominant token. It is transferred when the dominant token is transferred.

## The interfaces

```solidity
// A subordinate token can be associated to any ERC721 token.
// However, it it is necessary that the subordinate token is visible on services
// like marketplaces, the dominant token must propagate any Transfer event to the subordinate

// ERC165 interface id is 0x48b041fd
interface IERC721Dominant {
  function subordinateByIndex(uint256 index) external view returns (address);

  function isSubordinate(address subordinate_) external view returns (bool);

  function countSubordinates() external view returns (uint256);
}

```

```solidity
// A subordinate contract has no control on its own ownership.
// Whoever owns the main token owns the subordinate token.
// ERC165 interface id is 0x431694c0
interface IERC721Subordinate {
  // The function dominantToken() returns the address of the dominant token.
  function dominantToken() external view returns (address);

  // Most marketplaces do not see tokens that have not emitted an initial
  // transfer from address 0. This function allow to fix the issue, but
  // it is not mandatory — in same cases, the deployer may want the subordinate
  // being not visible on marketplaces.
  function emitTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external;
}

```

To avoid loops, it is paramount that the subordinate token sets the dominant token during the deployment and is not be able to change it.

## How to use it

Install the dependencies like

```
npm i @cruna/protocol
```

## How it works

You initialize the subordinate token passing the address of the main token and the subordinate takes anything from that. Look at some example in mocks and the testing.

What makes the difference is the base token uri. Change that, and everything will work great.

A simple example:

```solidity
// SPDX-License-Identifier: GPL3
pragma solidity 0.8.17;

import "@cruna/protocol/dominant-subordinate/ERC721Subordinate.sol";

contract MySubordinate is ERC721Subordinate {
  constructor(address myToken) ERC721Subordinate("MyToken", "MTK", myToken) {}
}

```

Another example, upgradeable

```solidity
// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@cruna/protocol/dominant-subordinate/ERC721SubordinateUpgradeable.sol";

contract MySubordinateUpgradeable is ERC721SubordinateUpgradeable, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(address myTokenEnumerableUpgradeable) public initializer {
    __ERC721EnumerableSubordinate_init("SuperToken", "SPT", myTokenEnumerableUpgradeable);
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override {}

  function getInterfaceId() public pure returns (bytes4) {
    return type(IERC721SubordinateUpgradeable).interfaceId;
  }
}

```

Notice that there is no reason to make the subordinate enumerable because we can query the dominant token to get all the ID owned by someone and apply that to the subordinate.

## Similar proposal

There are similar proposal that moves in the same realm.

[EIP-6150: Hierarchical NFTs](https://github.com/ethereum/EIPs/blob/ad986045e87d1e659bf36541df6fc13315c59bd7/EIPS/eip-6150.md) (discussion at https://ethereum-magicians.org/t/eip-6150-hierarchical-nfts-an-extension-to-erc-721/12173) is a proposal for a new standard for non-fungible tokens (NFTs) on the Ethereum blockchain that would allow NFTs to have a hierarchical structure, similar to a filesystem. This would allow for the creation of complex structures, such as NFTs that contain other NFTs, or NFTs that represent collections of other NFTs. The proposal is currently in the discussion phase, and has not yet been implemented on the Ethereum network. ERC721Subordinate focuses instead on a simpler scenario, trying to solve a specific problem in the simplest possible way.

EIP-3652 (https://ethereum-magicians.org/t/eip-3652-hierarchical-nft/6963) is very similar to EIP-6150. Both requires all the node following the standard. ERC721Subordinate is very different because it allows to create subordinates of existing, immutable NFTs, if it is not necessary to show the subordinate on marketplaces.

## Implementations

[Everdragons2PFP](https://github.com/ndujaLabs/everdragons2-core/blob/VP/contracts/Everdragons2PFP.sol)

Feel free to make a PR to add your contracts.

## History

For initial history changes, look at [the history in the previous repo](https://github.com/cruna-cc/ds-protocol#history)
