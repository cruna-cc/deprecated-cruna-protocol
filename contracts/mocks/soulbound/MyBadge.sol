// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "../../soulbound/Soulbound.sol";

contract MyBadge is Soulbound {
  constructor() Soulbound("MY Soulbound", "mBDG") {}

  function safeMint(address to, uint256 tokenId) public {
    _safeMint(to, tokenId);
  }

  function getInterfacesIds() public pure returns (bytes4, bytes4) {
    return (type(IERC721DefaultApprovable).interfaceId, type(IERC6982).interfaceId);
  }
}
