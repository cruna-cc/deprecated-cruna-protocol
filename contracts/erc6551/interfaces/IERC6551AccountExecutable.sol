// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC6551Account} from "./IERC6551Account.sol";
import {IERC6551Executable} from "./IERC6551Executable.sol";

/// @dev the ERC-165 identifier for this interface is `0x74420f4c`
interface IERC6551AccountExecutable is IERC6551Account, IERC6551Executable {

}
