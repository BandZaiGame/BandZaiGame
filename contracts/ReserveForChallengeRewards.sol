// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// some rewards have 60 Months unlocking period
// reserve for challenge will increase distribution pool for daily/weekly challenge each day a part of the 50M initial BZAI
contract ReserveForChallengeRewards is Ownable {
    IERC20 immutable BZAI;
    address public challengeRewardAddress;

    uint256 public daylyAddOn = 27397 * 1E18; //   60M / (365 * 5)
    uint256 public dayBeginingTimestamp;

    event ChallengeReserveEmpty();

    constructor(address _BZAI, uint256 _startingTimestamp) {
        BZAI = IERC20(_BZAI);
        dayBeginingTimestamp = _startingTimestamp;
        dayBeginingTimestamp = _getDayBegining();
    }

    function _getDayBegining() internal view returns (uint256) {
        uint256 timePassed = block.timestamp - dayBeginingTimestamp;
        uint256 daysPassed = timePassed / 1 days;

        return (dayBeginingTimestamp + (daysPassed * 1 days));
    }

    function setChallengeAddresses(address _address) external onlyOwner {
        require(challengeRewardAddress == address(0x0));
        challengeRewardAddress = _address;
    }

    function updateRewards() external returns (bool, uint256) {
        require(
            msg.sender == challengeRewardAddress,
            "only Rewards contract auth"
        );
        uint256 _dayBeganAt = _getDayBegining();
        if (dayBeginingTimestamp != _dayBeganAt) {
            dayBeginingTimestamp = _dayBeganAt;
            uint256 _balance = BZAI.balanceOf(address(this));

            if (_balance < daylyAddOn) {
                require(BZAI.transfer(msg.sender, _balance));
                emit ChallengeReserveEmpty();
                return (true, _balance);
            } else {
                require(BZAI.transfer(msg.sender, daylyAddOn));
                return (false, daylyAddOn);
            }
        } else {
            return (true, 0);
        }
    }
}
