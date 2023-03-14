// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";

// some rewards have 50 Months unlocking period
// reserve for winning pool will increase distribution pool each hour a part of the 150M initial BZAI
contract ReserveForWinRewards is Ownable {
    address public winRewardAddress;

    IERC20 immutable BZAI;

    // 70 000 000 in Reward winning found for incentize at beginning
    // 130 000 000 total reserve added to pool during 60 Months = 1521 Days => each hours (36 504Hours)
    // 130 000 000 / 36 504 = 3 561.25 BZAI
    uint256 public hourlyAddOn = 356125 * 1E16;
    uint256 public lastIncreaseCall;

    constructor(address _BZAI) {
        BZAI = IERC20(_BZAI);
        lastIncreaseCall = block.timestamp;
    }

    function setWinRewardAddresses(address _address) external onlyOwner {
        require(winRewardAddress == address(0x0));
        winRewardAddress = _address;
    }

    function updateRewards() external returns (bool, uint256) {
        require(msg.sender == winRewardAddress, "only Rewards contract auth");
        if (block.timestamp >= lastIncreaseCall + 3600) {
            lastIncreaseCall = block.timestamp;
            uint256 _balance = BZAI.balanceOf(address(this));
            if (_balance < hourlyAddOn) {
                require(BZAI.transfer(msg.sender, _balance));
                return (true, _balance);
            } else {
                require(BZAI.transfer(msg.sender, hourlyAddOn));
                return (false, hourlyAddOn);
            }
        } else {
            return (true, 0);
        }
    }
}
