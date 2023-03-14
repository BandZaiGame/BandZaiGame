// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenTest is ERC20, Ownable {
    constructor() ERC20("Token_test", "TEST") {
        _mint(msg.sender, 1000000000 * 1E18);
    }
}
