// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";

contract RewardsRankingFound is Ownable {
    IAddresses public gameAddresses;
    IERC20 immutable BZAI;

    IReserveForChalengeRewards IReserve;

    address public rankingContract;
    address public pvpRewardAddress;
    address public pveRewardAddress;

    uint256 immutable unlockBalancerTimestamp;

    bool public reserveFinished = false;

    uint256 public weeklyPercentageReward = 10; // 0,1%
    uint256 public dailyPercentageReward = 1; // 0,01%
    uint256 public dayBeginingTimestamp;
    uint256 public weekBeginingTimestamp;
    uint256 public lastBalancerCalled;

    mapping(uint256 => bool) _rewardSentThisDay;

    event GameAddressesSetted(address gameAddresses);
    event AddresseUpdated(
        address ranking,
        address pvpAddress,
        address pveAddress
    );
    event BalancerToPvp(uint256 amount);
    event BalancerToWinPve(uint256 amount);
    event RewardRankingPoolIncreased(uint256 amount);
    event PercentageRewardsUpdated(
        uint256 dayOldMetric,
        uint256 dayNewMetric,
        uint256 weekOldMetric,
        uint256 weekNewMetric
    );

    constructor(
        address _BZAI,
        address _reserve,
        uint256 _startingTimestamp
    ) {
        BZAI = IERC20(_BZAI);
        IReserve = IReserveForChalengeRewards(_reserve);
        unlockBalancerTimestamp = block.timestamp + 183 days;
        dayBeginingTimestamp = _startingTimestamp;
        dayBeginingTimestamp = _getDayBegining();
        weekBeginingTimestamp = _startingTimestamp;
        weekBeginingTimestamp = _getWeekBegining();
        lastBalancerCalled = block.timestamp;
    }

    modifier onlyGame() {
        require(msg.sender == rankingContract, "only Rewards contract auth");
        _;
    }

    function _getDayBegining() internal view returns (uint256) {
        uint256 timePassed = block.timestamp - dayBeginingTimestamp;
        uint256 daysPassed = timePassed / 1 days;

        return (dayBeginingTimestamp + (daysPassed * 1 days));
    }

    function _getWeekBegining() internal view returns (uint256) {
        uint256 timePassed = block.timestamp - weekBeginingTimestamp;
        uint256 weeksPassed = timePassed / 7 days;

        return (weekBeginingTimestamp + (weeksPassed * 7 days));
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
        rankingContract = gameAddresses.getAddressOf(
            AddressesInit.Addresses.RANKING
        );
        pvpRewardAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.REWARDS_PVP
        );
        pveRewardAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.REWARDS_WINNING_PVE
        );
        emit AddresseUpdated(
            rankingContract,
            pvpRewardAddress,
            pveRewardAddress
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

    function balancerToWinPveReward(uint256 _amount) external onlyOwner {
        require(pveRewardAddress != address(0x0), "Not setted");
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

        require(BZAI.transfer(pveRewardAddress, _amount));
        emit BalancerToWinPve(_amount);
    }

    function setPercentages(uint256 _daily, uint256 _weekly)
        external
        onlyOwner
    {
        require(
            _daily <= 500 && _weekly <= 500 && _daily >= 1 && _weekly >= 1,
            "values forbiden"
        );
        uint256 dayOldMetric = dailyPercentageReward;
        uint256 weekOldMetric = weeklyPercentageReward;
        weeklyPercentageReward = _weekly;
        dailyPercentageReward = _daily;
        emit PercentageRewardsUpdated(
            dayOldMetric,
            _daily,
            weekOldMetric,
            _weekly
        );
    }

    function getDailyRewards(address _rewardStoringAddress)
        external
        onlyGame
        returns (uint256)
    {
        uint256 _dayBeganAt = _getDayBegining();
        require(
            dayBeginingTimestamp != _dayBeganAt,
            "Reward already sent today"
        );
        dayBeginingTimestamp = _dayBeganAt;

        if (!reserveFinished) {
            uint256 _addOn;
            (reserveFinished, _addOn) = IReserve.updateRewards();
            emit RewardRankingPoolIncreased(_addOn);
        }

        uint256 _toSend = (BZAI.balanceOf(address(this)) *
            dailyPercentageReward) / 10000;

        // UPDATE AUDIT : Fix potential 0 token sent
        if (_toSend != 0) {
            require(BZAI.transfer(_rewardStoringAddress, _toSend));
        }
        return _toSend;
    }

    function getWeeklyRewards(address _rewardStoringAddress)
        external
        onlyGame
        returns (uint256)
    {
        uint256 _weekBeganAt = _getWeekBegining();
        require(
            weekBeginingTimestamp != _weekBeganAt,
            "Reward already sent this week"
        );
        weekBeginingTimestamp = _weekBeganAt;

        uint256 _toSend = (BZAI.balanceOf(address(this)) *
            weeklyPercentageReward) / 10000;

        // UPDATE AUDIT : Fix potential 0 token sent
        if (_toSend != 0) {
            require(BZAI.transfer(_rewardStoringAddress, _toSend));
        }
        return _toSend;
    }
}
