// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Interfaces.sol";

// Ranking of players
// Ranking is done with xp win in a fight, to be fairplay, xp potion doesn't count in the ranking
// each day at 00h00 UTC (summer time) Daily Ranking is reloaded. address in the ranking are automaticly rewarded with a part of ranking pool
// each monday at 00h00 UTC (summer time) Weekly Ranking is reloaded and players receives rewards in Payment contract
// Only top 20 players are stored
// if 2 players got same score, first who get the score is up in the ranking
contract DailyWeeklyRanking is Ownable, ReentrancyGuard {
    IAddresses public gameAddresses;
    IPayments public IPay;
    IRewardsRankingFound public IRewardsFounds;

    address public fightAddress;

    uint256 _dayNumber;
    uint256 _weekNumber;

    uint256[20] public percentageRewards = [
        15,
        12,
        10,
        8,
        8,
        7,
        7,
        6,
        6,
        5,
        4,
        3,
        2,
        1,
        1,
        1,
        1,
        1,
        1,
        1
    ];

    uint256 public dayBeginingTimestamp;
    uint256 public weekBeginingTimestamp;

    mapping(address => mapping(uint256 => uint256)) public dailyScore;
    mapping(address => mapping(uint256 => uint256)) public weeklyScore;

    // UPDATE AUDIT : Storing index in ranking for an user
    mapping(address => mapping(uint256 => uint256)) private _dailyIndex;
    mapping(address => mapping(uint256 => uint256)) private _weeklyIndex;

    struct ChallengeDatas {
        address user;
        uint256 userScore;
    }

    mapping(uint256 => ChallengeDatas[20]) private _dailyChallenge; // max 20 entries
    mapping(uint256 => uint256) private _dailyRewardsOfPastChallenge;
    mapping(uint256 => ChallengeDatas[20]) private _weeklyChallenge; // max 20 entries
    mapping(uint256 => uint256) private _weeklyRewardsOfPastChallenge;

    mapping(address => string) public addressToNickname;
    mapping(string => address) public nicknameToAddress;
    mapping(address => bool) public didntRespectNicknameRules;

    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address fightAddress,
        address payments,
        address rewardRankingFounds
    );

    // init contract with a starting date (Monday at 0h UTC for week start)
    constructor(uint256 _startingTimestamp) {
        dayBeginingTimestamp = _startingTimestamp;
        weekBeginingTimestamp = _startingTimestamp;
        _updateDayAndWeekBeginning();
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

        IPay = IPayments(
            gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
        );
        IRewardsFounds = IRewardsRankingFound(
            gameAddresses.getAddressOf(AddressesInit.Addresses.REWARDS_RANKING)
        );
        emit InterfacesUpdated(
            fightAddress,
            address(IPay),
            address(IRewardsFounds)
        );
    }

    function setNickname(string memory _nickname) external {
        require(bytes(_nickname).length <= 16, "name to long");
        require(
            nicknameToAddress[_nickname] == address(0x0),
            "Nickname already used by someone"
        );
        require(
            !didntRespectNicknameRules[msg.sender],
            "user didn't respect nickname rules"
        );

        if (
            keccak256(bytes(addressToNickname[msg.sender])) !=
            keccak256(bytes(""))
        ) {
            string memory oldNickName = addressToNickname[msg.sender];
            nicknameToAddress[oldNickName] = address(0x0);
        }
        addressToNickname[msg.sender] = _nickname;
        nicknameToAddress[_nickname] = msg.sender;
    }

    function updateNicknameByAdmin(string memory _nickname, address _user)
        external
        onlyOwner
    {
        didntRespectNicknameRules[_user] = true;
        addressToNickname[_user] = _nickname;
        nicknameToAddress[_nickname] = _user;
    }

    function canUseThisNickname(string memory _nickname)
        external
        view
        returns (bool)
    {
        return nicknameToAddress[_nickname] == address(0x0);
    }

    function getDailyRanking()
        external
        view
        returns (ChallengeDatas[20] memory ranking, string[20] memory names)
    {
        (uint256 _dayNb, ) = _getDayAndWeekRankingCounter();
        string[20] memory _names;
        for (uint256 i; i < 20; ) {
            _names[i] = addressToNickname[_dailyChallenge[_dayNb][i].user];
            unchecked {
                ++i;
            }
        }
        return (_dailyChallenge[_dayNb], _names);
    }

    function getWeeklyRanking()
        external
        view
        returns (ChallengeDatas[20] memory ranking, string[20] memory names)
    {
        (, uint256 _weekNb) = _getDayAndWeekRankingCounter();
        string[20] memory _names;
        for (uint256 i; i < 20; ) {
            _names[i] = addressToNickname[_weeklyChallenge[_weekNb][i].user];
            unchecked {
                ++i;
            }
        }
        return (_weeklyChallenge[_weekNb], _names);
    }

    function getDayAndWeekRankingCounter()
        external
        view
        returns (uint256 dayNumber, uint256 weekNumber)
    {
        return _getDayAndWeekRankingCounter();
    }

    function _getDayAndWeekRankingCounter()
        internal
        view
        returns (uint256 dayNumber, uint256 weekNumber)
    {
        uint256 _dayBegining = _getDayBegining();
        if (_dayBegining >= dayBeginingTimestamp + 1 days) {
            if (_dayBegining >= weekBeginingTimestamp + 7 days) {
                return (_dayNumber + 1, _weekNumber + 1);
            } else {
                return (_dayNumber + 1, _weekNumber);
            }
        } else {
            return (_dayNumber, _weekNumber);
        }
    }

    function getPastDailyRanking(uint256 _dayNum)
        external
        view
        returns (
            ChallengeDatas[20] memory ranking,
            uint256 rewards,
            string[20] memory names
        )
    {
        string[20] memory _names;
        for (uint256 i; i < 20; ) {
            _names[i] = addressToNickname[_dailyChallenge[_dayNum][i].user];
            unchecked {
                ++i;
            }
        }
        return (
            _dailyChallenge[_dayNum],
            _dailyRewardsOfPastChallenge[_dayNum],
            _names
        );
    }

    function getPastWeeklyRanking(uint256 _weekNum)
        external
        view
        returns (
            ChallengeDatas[20] memory ranking,
            uint256 rewards,
            string[20] memory names
        )
    {
        string[20] memory _names;
        for (uint256 i; i < 20; ) {
            _names[i] = addressToNickname[_weeklyChallenge[_weekNum][i].user];
            unchecked {
                ++i;
            }
        }
        return (
            _weeklyChallenge[_weekNum],
            _weeklyRewardsOfPastChallenge[_weekNum],
            _names
        );
    }

    function setPercentageRewards(uint256[20] memory _percent)
        external
        onlyOwner
    {
        uint256 _total;
        for (uint256 i; i < 20; ) {
            _total += _percent[i];
            unchecked {
                ++i;
            }
        }
        require(_total == 100, "Bad percentage !");
        for (uint256 i; i < 20; ) {
            percentageRewards[i] = _percent[i];
            unchecked {
                ++i;
            }
        }
    }

    function getDayBegining() external view returns (uint256) {
        return _getDayBegining();
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

    function _updateDayAndWeekBeginning() internal returns (bool) {
        uint256 dayBegining = _getDayBegining();
        if (dayBeginingTimestamp != dayBegining) {
            dayBeginingTimestamp = dayBegining;
            ++_dayNumber;
            _payDailyWinners();
            uint256 weekBegining = _getWeekBegining();
            if (weekBeginingTimestamp != weekBegining) {
                weekBeginingTimestamp = weekBegining;
                ++_weekNumber;
                _payWeeklyWinners();
            }
        }
        return true;
    }

    function _payDailyWinners() internal {
        if (_dailyChallenge[_dayNumber - 1][0].user == address(0x0)) {
            return;
        }

        uint256 _rewards = IRewardsFounds.getDailyRewards(address(IPay));
        _dailyRewardsOfPastChallenge[_dayNumber - 1] = _rewards;

        uint256 unDistributed;

        for (uint256 i; i < 20; ) {
            uint256 _toSend = (_rewards * percentageRewards[i]) / 100;
            address _user = _dailyChallenge[_dayNumber - 1][i].user;

            if (_user != address(0x0)) {
                require(IPay.rewardPlayer(_user, _toSend, 0, 0, false));
            } else {
                unDistributed += _toSend;
            }
            unchecked {
                ++i;
            }
        }
        if (unDistributed != 0) {
            require(IPay.burnUndistributedRewards(unDistributed));
        }
    }

    function _payWeeklyWinners() internal {
        if (_weeklyChallenge[_weekNumber - 1][0].user == address(0x0)) {
            return;
        }

        uint256 _rewards = IRewardsFounds.getWeeklyRewards(address(IPay));
        _weeklyRewardsOfPastChallenge[_weekNumber - 1] = _rewards;

        uint256 unDistributed;

        for (uint256 i; i < 20; ) {
            uint256 _toSend = (_rewards * percentageRewards[i]) / 100;
            address _user = _weeklyChallenge[_weekNumber - 1][i].user;

            if (_user != address(0x0)) {
                require(IPay.rewardPlayer(_user, _toSend, 0, 0, false));
            } else {
                unDistributed += _toSend;
            }
            unchecked {
                ++i;
            }
        }
        if (unDistributed != 0) {
            require(IPay.burnUndistributedRewards(unDistributed));
        }
    }

    function _updateCountersScores(address _user, uint256 _xpWin)
        internal
        returns (bool)
    {
        dailyScore[_user][_dayNumber] += _xpWin;
        weeklyScore[_user][_weekNumber] += _xpWin;

        return true;
    }

    function updatePlayerRankings(address _user, uint256 _xpWin)
        external
        nonReentrant
        returns (bool)
    {
        require(
            msg.sender == fightAddress,
            "Only Game Fighting contract accepted"
        );
        // update
        require(_updateDayAndWeekBeginning());
        require(_updateCountersScores(_user, _xpWin));
        _updateDailyRanking(_user);
        _updateWeeklyRanking(_user);
        return (true);
    }

    function _updateDailyRanking(address _user) internal {
        ChallengeDatas[20] storage d = _dailyChallenge[_dayNumber];
        ChallengeDatas memory p = ChallengeDatas(
            _user,
            dailyScore[_user][_dayNumber]
        );

        if (d[19].userScore >= p.userScore) {
            // if player doesn't have better score than 20th ranking player
            return;
        } else if (d[0].user == _user) {
            //if player is on first rank, just update his score
            d[0].userScore = p.userScore;
            return;
        } else {
            // get ranking
            uint256 myIndex = _dailyIndex[_user][_dayNumber];
            if (myIndex != 0 && myIndex != 20) {
                //update score
                d[myIndex].userScore = p.userScore;
            } else {
                myIndex = 19;
                address _tempChallenger = d[19].user;

                if (_tempChallenger != address(0)) {
                    unchecked {
                        ++_dailyIndex[d[19].user][_dayNumber];
                    }
                }
            }

            while (d[myIndex - 1].userScore < p.userScore) {
                // store user
                ChallengeDatas memory c = d[myIndex - 1];
                if (c.user != address(0x0)) {
                    // replace user only if not address(0)
                    ++_dailyIndex[c.user][_dayNumber];
                    d[myIndex] = c;
                }
                unchecked {
                    --myIndex;
                }
                if (myIndex == 0) {
                    break;
                }
            }

            _dailyIndex[_user][_dayNumber] = myIndex;
            d[myIndex] = p;
        }
    }

    function _updateWeeklyRanking(address _user) internal {
        ChallengeDatas[20] storage d = _weeklyChallenge[_weekNumber];
        ChallengeDatas memory p = ChallengeDatas(
            _user,
            weeklyScore[_user][_weekNumber]
        );

        if (d[19].userScore >= p.userScore) {
            // if player doesn't have better score than 20th ranking player
            return;
        } else if (d[0].user == _user) {
            //if player is on first rank, just update his score
            d[0].userScore = p.userScore;
            return;
        } else {
            // get ranking
            uint256 myIndex = _weeklyIndex[_user][_weekNumber];
            if (myIndex != 0 && myIndex != 20) {
                //update score
                d[myIndex].userScore = p.userScore;
            } else {
                myIndex = 19;
                address _tempChallenger = d[19].user;

                if (_tempChallenger != address(0)) {
                    unchecked {
                        ++_weeklyIndex[d[19].user][_weekNumber];
                    }
                }
            }

            while (d[myIndex - 1].userScore < p.userScore) {
                // store user
                ChallengeDatas memory c = d[myIndex - 1];
                if (c.user != address(0x0)) {
                    // replace user only if not address(0)
                    ++_weeklyIndex[c.user][_weekNumber];
                    d[myIndex] = c;
                }
                unchecked {
                    --myIndex;
                }
                if (myIndex == 0) {
                    break;
                }
            }

            _weeklyIndex[_user][_weekNumber] = myIndex;
            d[myIndex] = p;
        }
    }
}
