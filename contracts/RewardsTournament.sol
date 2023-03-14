// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// for futur V2, devs will setup a PvP tournament mode
// this vesting contract allows owner to get 1/40 of those tokens after 6 months lock and during 40months
contract RewardsTournament is Ownable {
    IERC20 immutable BZAI;
    uint256 public unlockingTimestamp;
    uint256 public futurPartClaimaible;

    address public tournamentFound;

    event RewardForTournamentClaimed(uint256 amount);
    event TournamentFoundAddressSetted(address foundAddress);

    constructor(address _BZAI) {
        BZAI = IERC20(_BZAI);
        unlockingTimestamp = block.timestamp + 183 days;
    }

    function setTournamentFoundAddress(address _address) external onlyOwner {
        tournamentFound = _address;
        emit TournamentFoundAddressSetted(_address);
    }

    function getRewardsForTournament() external onlyOwner {
        require(block.timestamp >= unlockingTimestamp, "Too soon");
        require(tournamentFound != address(0), "Tournament found not setted");
        unlockingTimestamp += 30 days;
        if (futurPartClaimaible == 0) {
            futurPartClaimaible = BZAI.balanceOf(address(this)) / 40;
        }
        if (BZAI.balanceOf(address(this)) < futurPartClaimaible) {
            futurPartClaimaible = BZAI.balanceOf(address(this));
        }
        if (futurPartClaimaible != 0) {
            require(BZAI.transfer(msg.sender, futurPartClaimaible));
            emit RewardForTournamentClaimed(futurPartClaimaible);
        }
    }
}
