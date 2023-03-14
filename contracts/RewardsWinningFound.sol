// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Interfaces.sol";

// Here is the reward PvE pool
// where player can get rewarded by winning versus environment
contract RewardsWinningFound is Ownable, ReentrancyGuard {
    IAddresses public gameAddresses;

    IERC20 immutable BZAI;
    IReserveForWinRewards IReserve;

    uint256 public unlockBalancerTimestamp;

    address public fightAddress;
    address public pvpRewardAddress;
    address public rankingRewardAddress;
    address public paymentsAddress;
    uint256 public lastBalancerCalled;

    bool public reserveFinished = false;

    uint256 bonusMult = 120;

    uint256 public rewardPortion = 10000000; // 0.00001%  //10 000 000 => Arround 5 BZAI at begining if pool = 50M

    uint256 public lastTimeUpdated;

    event GameAddressesSetted(address gameAddresses);
    event AddresseUpdated(
        address fight,
        address pvpAddress,
        address rankingAddress,
        address payments
    );
    event BalancerToPvp(uint256 amount);
    event BalancerToRanking(uint256 amount);
    event RewardPortionUpdated(uint256 previousPortion, uint256 newPortion);
    event BonusWinMultUpdated(uint256 previousMult, uint256 newMult);
    event RewardWinPvePoolIncreased(uint256 amount);

    constructor(address _BZAI, address _reserve) {
        BZAI = IERC20(_BZAI);
        IReserve = IReserveForWinRewards(_reserve);
        lastTimeUpdated = block.timestamp;
        unlockBalancerTimestamp = block.timestamp + 183 days;
        lastBalancerCalled = block.timestamp;
    }

    modifier onlyGame() {
        require(msg.sender == fightAddress, "only Game auth");
        _;
    }

    function setGameAddresses(address _address) external onlyOwner {
        require(
            address(gameAddresses) == address(0x0),
            "game addresses already setted"
        );
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function updateInterfaces() external {
        fightAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.FIGHT
        );
        pvpRewardAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.REWARDS_PVP
        );
        rankingRewardAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.REWARDS_RANKING
        );
        paymentsAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.PAYMENTS
        );
        emit AddresseUpdated(
            fightAddress,
            pvpRewardAddress,
            rankingRewardAddress,
            paymentsAddress
        );
    }

    // balancer function, is necessary to balancer pools if a pool drop to much
    // only can use it after 6 months lock
    function balancerToPvpReward(uint256 _amount) external onlyOwner {
        require(pvpRewardAddress != address(0x0), "Not setted");
        require(block.timestamp >= unlockBalancerTimestamp, "too soon");
        require(
            _amount <= BZAI.balanceOf(address(this)) / 10,
            "not much than 10%"
        );
        require(
            block.timestamp >= lastBalancerCalled + 1 days,
            "too soon to balance poolz"
        );
        lastBalancerCalled = block.timestamp;

        require(BZAI.transfer(pvpRewardAddress, _amount));
        emit BalancerToPvp(_amount);
    }

    function balancerToRankingReward(uint256 _amount) external onlyOwner {
        require(rankingRewardAddress != address(0x0), "Not setted");
        require(block.timestamp >= unlockBalancerTimestamp, "too soon");
        require(
            _amount <= BZAI.balanceOf(address(this)) / 10,
            "not much than 10%"
        );
        require(
            block.timestamp >= lastBalancerCalled + 1 days,
            "too soon to balance poolz"
        );
        lastBalancerCalled = block.timestamp;

        require(BZAI.transfer(rankingRewardAddress, _amount));
        emit BalancerToRanking(_amount);
    }

    function setRewardPortion(uint256 _rewardPortion) external onlyOwner {
        require(
            _rewardPortion >= 10000 && _rewardPortion <= 100000000,
            "Value forbiden"
        );
        uint256 _previousPortion = rewardPortion;
        rewardPortion = _rewardPortion;
        emit RewardPortionUpdated(_previousPortion, _rewardPortion);
    }

    function setBonusMult(uint256 _bonus) external onlyOwner {
        require(
            _bonus >= 100 && _bonus <= 140,
            "bonus multiplicator not match"
        );
        uint256 _previousMult = bonusMult;
        bonusMult = _bonus;
        emit BonusWinMultUpdated(_previousMult, _bonus);
    }

    function getWinningRewards(uint256 level, bool bonus)
        external
        onlyGame
        nonReentrant
        returns (uint256)
    {
        if (!reserveFinished) {
            if (block.timestamp >= (lastTimeUpdated + 3600)) {
                lastTimeUpdated = block.timestamp;
                uint256 _addOn;
                (reserveFinished, _addOn) = IReserve.updateRewards();
                emit RewardWinPvePoolIncreased(_addOn);
            }
        }

        uint256 multiplier;
        if (level >= 50) {
            multiplier = 1000;
        } else {
            multiplier = (level * 18) + 100;
        }

        uint256 _toSend = BZAI.balanceOf(address(this)) / rewardPortion;

        //each level add to multiplier 0.18 => 1.00(level 0) => 10.00(level 50)
        _toSend = (_toSend * multiplier) / 100;

        // if player got 2 x more points than challenger => apply bonus multiplicator
        if (bonus) {
            _toSend = (_toSend * bonusMult) / 100;
        }

        require(BZAI.transfer(paymentsAddress, _toSend));
        return _toSend;
    }
}
