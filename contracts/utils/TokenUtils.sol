// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {IProtectedERC721} from "../protected-nft/IProtectedERC721.sol";
import {IFlexiVault} from "../vaults/IFlexiVault.sol";
import {IActors} from "../protected-nft/IActors.sol";

//import {console} from "hardhat/console.sol";

library TokenUtils {
  error TheERC721IsAProtector();

  function isERC721(address asset) public view returns (bool) {
    try IERC165(asset).supportsInterface(type(IProtectedERC721).interfaceId) returns (bool result) {
      if (result) revert TheERC721IsAProtector();
    } catch {}
    try IERC165(asset).supportsInterface(type(IERC721).interfaceId) returns (bool result) {
      return result;
    } catch {}
    return false;
  }

  // It should work fine with ERC20 and ERC777
  function isERC20(address asset) public view returns (bool) {
    if (!isERC721(asset)) {
      // we exclude ERC721 because totalSupply can be also returned
      // by enumerable ERC721
      try IERC20(asset).totalSupply() returns (uint256 result) {
        return result > 0;
      } catch {}
    }
    return false;
  }

  function isERC1155(address asset) public view returns (bool) {
    // will revert if asset does not implement IERC165
    try IERC165(asset).supportsInterface(type(IERC1155).interfaceId) returns (bool result) {
      return result;
    } catch {}
    return false;
  }

  function version() external pure returns (string memory) {
    return "1.0.0";
  }

  function isTokenUtils() external pure returns (bytes4) {
    return TokenUtils.isTokenUtils.selector;
  }

  function hashWithdrawRequest(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32) {
    return
      keccak256(
        abi.encode("\x19\x01", block.chainid, address(this), owningTokenId, asset, id, amount, beneficiary, timestamp, validFor)
      );
  }

  function hashRecipientRequest(
    address owner,
    address recipient,
    IActors.Level level,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32) {
    return keccak256(abi.encode("\x19\x01", block.chainid, address(this), owner, recipient, level, timestamp, validFor));
  }

  function hashBeneficiaryRequest(
    address owner,
    address beneficiary,
    IActors.Status status,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32) {
    return keccak256(abi.encode("\x19\x01", block.chainid, address(this), owner, beneficiary, status, timestamp, validFor));
  }

  function hashWithdrawsRequest(
    uint256 owningTokenId,
    IFlexiVault.TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32) {
    return
      keccak256(
        abi.encode(
          "\x19\x01",
          block.chainid,
          address(this),
          owningTokenId,
          tokenTypes,
          assets,
          ids,
          amounts,
          beneficiaries,
          timestamp,
          validFor
        )
      );
  }

  function hashEjectRequest(uint256 owningTokenId, uint256 timestamp, uint256 validFor) external view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", block.chainid, address(this), owningTokenId, timestamp, validFor));
  }

  function hashTransferRequest(uint256 tokenId, address to, uint256 timestamp, uint256 validFor) public view returns (bytes32) {
    return keccak256(abi.encode("\x19\x01", block.chainid, address(this), tokenId, to, timestamp, validFor));
  }
}
