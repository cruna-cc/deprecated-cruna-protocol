// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bulls is ERC20, Ownable {
  constructor() ERC20("Bulls", "BULLS") {}

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }
}