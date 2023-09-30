// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC6551Account} from "erc6551/interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "erc6551/interfaces/IERC6551Executable.sol";

interface IERC6551AccountExecutable is IERC6551Account, IERC6551Executable {}
