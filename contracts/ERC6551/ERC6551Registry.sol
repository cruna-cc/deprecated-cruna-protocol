// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// from https://github.com/erc6551/reference

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IERC6551Registry} from "./IERC6551Registry.sol";
import {ERC6551BytecodeLib} from "./lib/ERC6551BytecodeLib.sol";

//import {console} from "hardhat/console.sol";

contract ERC6551Registry is IERC6551Registry, IERC165 {
  error InitializationFailed();

  function createAccount(
    address implementation,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId,
    uint256 salt,
    bytes calldata initData
  ) external returns (address) {
    bytes memory code = ERC6551BytecodeLib.getCreationCode(implementation, chainId, tokenContract, tokenId, salt);

    address _account = Create2.computeAddress(bytes32(salt), keccak256(code));

    if (_account.code.length != 0) return _account;

    emit AccountCreated(_account, implementation, chainId, tokenContract, tokenId, salt);

    _account = Create2.deploy(0, bytes32(salt), code);

    if (initData.length != 0) {
      // solhint-disable-next-line avoid-low-level-calls
      (bool success, ) = _account.call(initData);
      if (!success) revert InitializationFailed();
    }

    return _account;
  }

  function account(
    address implementation,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId,
    uint256 salt
  ) external view returns (address) {
    bytes32 bytecodeHash = keccak256(ERC6551BytecodeLib.getCreationCode(implementation, chainId, tokenContract, tokenId, salt));

    return Create2.computeAddress(bytes32(salt), bytecodeHash);
  }

  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return (interfaceId == type(IERC6551Registry).interfaceId || interfaceId == type(IERC165).interfaceId);
  }
}
