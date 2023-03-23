// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UselessWeapons is ERC1155, Ownable {
  constructor() ERC1155("https://uselessweapons.com/list/") {}

  function setURI(string memory newuri_) public onlyOwner {
    _setURI(newuri_);
  }

  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) public onlyOwner {
    _mintBatch(to, ids, amounts, data);
  }
}
