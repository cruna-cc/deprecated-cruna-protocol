// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// from https://github.com/erc6551/reference

/// @author: manifold.xyz

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "./IERC6551Account.sol";
import "./lib/ERC6551AccountLib.sol";

//import "hardhat/console.sol";

/**
 * @title ERC6551AccountUpgradeable
 * @notice A lightweight smart contract wallet implementation that can be used by ERC6551AccountProxy
 */
contract ERC6551Account is IERC165, IERC721Receiver, IERC1155Receiver, IERC6551Account, IERC1271 {
  // Padding for initializable values
  uint256 private _nonce;

  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return (interfaceId == type(IERC6551Account).interfaceId ||
      interfaceId == type(IERC1155Receiver).interfaceId ||
      interfaceId == type(IERC721Receiver).interfaceId ||
      interfaceId == type(IERC165).interfaceId);
  }

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
    (uint256 _chainId, address _contractAddress, uint256 _tokenId) = ERC6551AccountLib.token();
    require(
      _chainId != block.chainid || receivedTokenAddress != _contractAddress || receivedTokenId != _tokenId,
      "Cannot own yourself"
    );

    address currentOwner = owner();
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

  /**
   * @dev {See IERC6551Account-token}
   */
  function token() external view override returns (uint256, address, uint256) {
    return ERC6551AccountLib.token();
  }

  /**
   * @dev {See IERC6551Account-owner}
   */
  function owner() public view override returns (address) {
    (uint256 chainId, address contractAddress, uint256 tokenId) = ERC6551AccountLib.token();
    if (chainId != block.chainid) return address(0);
    return IERC721(contractAddress).ownerOf(tokenId);
  }

  /**
   * @dev {See IERC6551Account-nonce}
   */
  function nonce() external view override returns (uint256) {
    return _nonce;
  }

  /**
   * @dev {See IERC6551Account-owner}
   */
  function executeCall(
    address _target,
    uint256 _value,
    bytes calldata _data
  ) external payable override returns (bytes memory _result) {
    require(owner() == msg.sender, "Caller is not owner");
    ++_nonce;
    bool success;
    // solhint-disable-next-line avoid-low-level-calls
    (success, _result) = _target.call{value: _value}(_data);
    require(success, string(_result));
    emit TransactionExecuted(_target, _value, _data);
    return _result;
  }

  receive() external payable {}

  function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
    bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);
    if (isValid) {
      return IERC1271.isValidSignature.selector;
    }

    return "";
  }

  function isERC6551Account() external pure returns (bool) {
    return true;
  }
}