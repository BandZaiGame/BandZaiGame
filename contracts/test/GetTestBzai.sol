// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GetTestBzai {
    mapping(address => uint256) _lastClaim;
    IERC20 BZAI;

    constructor(IERC20 _bzai) {
        BZAI = _bzai;
    }

    function claimBzai() external {
        require(
            _lastClaim[msg.sender] == 0 ||
                block.timestamp >= _lastClaim[msg.sender] + 1 days,
            "Only one claim by day"
        );
        _lastClaim[msg.sender] = block.timestamp;

        if (BZAI.balanceOf(address(this)) < 1000 * 1E18) {
            revert();
        } else {
            BZAI.transfer(msg.sender, 1000 * 1E18);
        }
    }
}
