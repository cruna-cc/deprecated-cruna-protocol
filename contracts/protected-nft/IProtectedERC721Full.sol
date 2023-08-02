// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {IERC721, IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IProtectedERC721} from "./IProtectedERC721.sol";

// erc165 interfaceId 0x8dca4bea
interface IProtectedERC721Full is IProtectedERC721, IERC721, IERC721Enumerable {

}
