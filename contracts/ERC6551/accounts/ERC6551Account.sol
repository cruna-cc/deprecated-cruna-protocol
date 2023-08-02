// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// from https://github.com/erc6551/reference

/// @author: manifold.xyz

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import {IERC6551Account} from "../interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "../interfaces/IERC6551Executable.sol";
import {ERC6551AccountLib} from "../lib/ERC6551AccountLib.sol";

//import {console} from "hardhat/console.sol";

contract ERC6551Account is IERC165, IERC721Receiver, IERC1155Receiver, IERC6551Account, IERC6551Executable, IERC1271 {
  // Padding for initializable values
  uint256 internal _state;

  receive() external payable {}

  function execute(
    address to,
    uint256 value,
    bytes calldata data,
    uint256 operation
  ) external payable returns (bytes memory result) {
    require(msg.sender == accountOwner(), "Caller is not owner");
    require(operation == 0, "Only calls are supported");

    ++_state;

    bool success;
    (success, result) = to.call{value: value}(data);

    if (!success) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        revert(add(result, 32), mload(result))
      }
    }
  }

  function isValidSigner(address signer, bytes calldata) external view returns (bytes4) {
    if (signer == accountOwner()) {
      return IERC6551Account.isValidSigner.selector;
    }
    return bytes4(0);
  }

  function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
    bool isValid = SignatureChecker.isValidSignatureNow(accountOwner(), hash, signature);
    if (isValid) {
      return IERC1271.isValidSignature.selector;
    }
    return "";
  }

  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return
      interfaceId == type(IERC6551Account).interfaceId ||
      interfaceId == type(IERC6551Executable).interfaceId ||
      interfaceId == type(IERC1155Receiver).interfaceId ||
      interfaceId == type(IERC721Receiver).interfaceId ||
      interfaceId == type(IERC165).interfaceId;
  }

  /**
   * @dev {See IERC6551Account-token}
   */
  function token() public view override returns (uint256, address, uint256) {
    return ERC6551AccountLib.token();
  }

  /**
   * @dev {See IERC6551Account-state}
   */
  function state() external view override returns (uint256) {
    return _state;
  }

  // receivers

  function onERC721Received(address, address, uint256 receivedTokenId, bytes memory) public view returns (bytes4) {
    _revertIfOwnershipCycle(msg.sender, receivedTokenId);
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address,
    address,
    uint256[] memory,
    uint256[] memory,
    bytes memory
  ) public pure returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }

  /**
   * @dev Helper method to check if a received token is in the ownership chain of the wallet.
   * @param receivedTokenAddress The address of the token being received.
   * @param receivedTokenId The ID of the token being received.
   */
  function _revertIfOwnershipCycle(address receivedTokenAddress, uint256 receivedTokenId) internal view {
    (uint256 _chainId, address _contractAddress, uint256 _tokenId) = token();
    require(
      _chainId != block.chainid || receivedTokenAddress != _contractAddress || receivedTokenId != _tokenId,
      "Cannot own yourself"
    );

    address currentOwner = accountOwner();
    require(currentOwner != address(this), "Token in ownership chain");
    uint256 depth = 0;
    while (currentOwner.code.length > 0) {
      try IERC6551Account(payable(currentOwner)).token() returns (uint256 chainId, address contractAddress, uint256 tokenId) {
        require(
          chainId != block.chainid || contractAddress != receivedTokenAddress || tokenId != receivedTokenId,
          "Token in ownership chain"
        );
        // Advance up the ownership chain
        currentOwner = IERC721(contractAddress).ownerOf(tokenId);
        require(currentOwner != address(this), "Token in ownership chain");
      } catch {
        break;
      }
      unchecked {
        ++depth;
      }
      if (depth == 5) revert("Ownership chain too deep");
    }
  }

  function accountOwner() public view returns (address) {
    (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
    if (chainId != block.chainid) return address(0);
    return IERC721(tokenContract).ownerOf(tokenId);
  }
}
