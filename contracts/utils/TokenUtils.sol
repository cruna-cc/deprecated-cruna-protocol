// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "../protected-nft/IProtectedERC721.sol";
import "./ITokenUtils.sol";
import "./IVersioned.sol";

//import "hardhat/console.sol";

contract TokenUtils is ITokenUtils, IVersioned {
  error TheERC721IsAProtector();

  function isERC721(address asset) public view override returns (bool) {
    try IERC165(asset).supportsInterface(type(IProtectedERC721).interfaceId) returns (bool result) {
      if (result) revert TheERC721IsAProtector();
    } catch {}
    try IERC165(asset).supportsInterface(type(IERC721).interfaceId) returns (bool result) {
      return result;
    } catch {}
    return false;
  }

  // It should work fine with ERC20 and ERC777
  function isERC20(address asset) public view override returns (bool) {
    if (!isERC721(asset)) {
      // we exclude ERC721 because totalSupply can be also returned
      // by enumerable ERC721
      try IERC20(asset).totalSupply() returns (uint256 result) {
        return result > 0;
      } catch {}
    }
    return false;
  }

  function isERC1155(address asset) public view override returns (bool) {
    // will revert if asset does not implement IERC165
    try IERC165(asset).supportsInterface(type(IERC1155).interfaceId) returns (bool result) {
      return result;
    } catch {}
    return false;
  }

  function version() external pure override returns (string memory) {
    return "1.0.0";
  }

  function isTokenUtils() external pure override returns (bytes4) {
    return this.isTokenUtils.selector;
  }

  function hashWithdrawRequest(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary,
    uint256 timestamp,
    uint validFor
  ) external view override returns (bytes32) {
    return
      keccak256(
        abi.encodePacked("\x19\x01", block.chainid, owningTokenId, asset, id, amount, beneficiary, timestamp, validFor)
      );
  }

  function hashWithdrawsRequest(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries,
    uint256 timestamp,
    uint validFor
  ) external view override returns (bytes32) {
    return
      keccak256(
        abi.encodePacked("\x19\x01", block.chainid, owningTokenId, assets, ids, amounts, beneficiaries, timestamp, validFor)
      );
  }

  function hashEjectRequest(uint256 owningTokenId, uint256 timestamp, uint validFor) external view override returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", block.chainid, owningTokenId, timestamp, validFor));
  }
}
