// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {IActors} from "./IActors.sol";

// erc165 interfaceId 0x8dca4bea
interface IProtectedERC721 {
  /**
   * @dev Transfers a token to a recipient usign a valid signed transferRequest
   * @notice The function MUST be executed by the owner
   * @param tokenId The token id
   * @param to The address of the recipient
   * @param timestamp The timestamp of the transfer request
   * @param signature The signature of the transfer request, signed by an active protector
   */
  function protectedTransfer(
    uint256 tokenId,
    address to,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;

  function managedTransfer(uint256 tokenId, address to) external;
}
