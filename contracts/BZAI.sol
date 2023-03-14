// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BZAI is ERC20, Ownable {
    constructor() ERC20("https://www.bandzai.games", "BZAI") {
        _mint(msg.sender, 1000000000 * 1E18);
    }

    function burn(uint256 _amount) external returns (bool) {
        _burn(msg.sender, _amount);
        return true;
    }

    // allows to withdraw token accidently sent to contract
    function withdraw(ERC20 _token) external onlyOwner returns (bool) {
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
        return true;
    }
}
