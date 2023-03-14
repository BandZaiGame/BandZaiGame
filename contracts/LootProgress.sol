// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// if a player make a fight each day, he will won loot box on 7th day of each week
// loot are composed of potion, and each 5 weeks, player can get an Egg
contract LootProgress is Ownable {
    IAddresses public gameAddresses;

    address public fightAddress;
    IRanking public IRank;
    IPotions public Potions;
    IEggs public Eggs;
    IOracle public Oracle;

    struct WeeklyLoot {
        bool claimable;
        bool claimed;
    }

    struct Progress {
        uint256 lastActionTimestamp;
        uint256 dayOfWeek;
        uint256 weekNumber;
        uint256 lastLootClaimable;
        mapping(uint256 => WeeklyLoot) weeklyLootClaimed;
    }

    mapping(address => Progress) _progress;

    // UPDATE AUDIT : add a dayly loot to claim (1 potion by day if user made a fight)
    mapping(uint256 => mapping(address => bool)) _dailyLootClaimed; //_dailyLootClaimed[currentDay] => currentDay get on DailyWeeklyRanking contract getDayAndWeekRankingCounter()

    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address fightAddress,
        address rankingAddress,
        address potionsAddress,
        address eggsAddress,
        address oracleAddress
    );
    event NewLootResult(
        address indexed user,
        uint256 lootType,
        uint256[4] loots
    ); // lootype 0 = Potion || 1 = Egg

    event DailyLootClaimed(address indexed user, uint256 potionId);

    modifier onlyGame() {
        require(msg.sender == fightAddress, "Only game authorized");
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
        IRank = IRanking(
            gameAddresses.getAddressOf(AddressesInit.Addresses.RANKING)
        );
        Potions = IPotions(
            gameAddresses.getAddressOf(AddressesInit.Addresses.POTIONS_NFT)
        );
        Eggs = IEggs(
            gameAddresses.getAddressOf(AddressesInit.Addresses.EGGS_NFT)
        );
        Oracle = IOracle(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ORACLE)
        );
        emit InterfacesUpdated(
            fightAddress,
            address(IRank),
            address(Potions),
            address(Eggs),
            address(Oracle)
        );
    }

    function getUserProgress(address _user)
        external
        view
        returns (
            uint256 lastActionTimestamp,
            uint256 dayOfWeek,
            uint256 weekNumber,
            uint256 lastLootClaimable
        )
    {
        return _getUserProgress(_user);
    }

    function _getUserProgress(address _user)
        internal
        view
        returns (
            uint256 lastActionTimestamp,
            uint256 dayOfWeek,
            uint256 weekNumber,
            uint256 lastLootClaimable
        )
    {
        Progress storage p = _progress[_user];
        uint256 _beginningDay = _getDayBegining();

        if (p.lastActionTimestamp == 0) {
            return (0, 0, 1, 0);
        } else if (
            p.lastActionTimestamp >= _beginningDay ||
            _beginningDay - p.lastActionTimestamp <= 1 days
        ) {
            return (
                p.lastActionTimestamp,
                p.dayOfWeek,
                p.weekNumber,
                p.lastLootClaimable
            );
        } else if (_beginningDay - p.lastActionTimestamp <= 7 days) {
            return (
                p.lastActionTimestamp,
                0,
                p.weekNumber,
                p.lastLootClaimable
            );
        } else if (
            _beginningDay - p.lastActionTimestamp > 7 days &&
            _beginningDay - p.lastActionTimestamp < 14 days
        ) {
            return (
                p.lastActionTimestamp,
                0,
                p.weekNumber > 1 ? p.weekNumber - 1 : 1,
                p.lastLootClaimable
            );
        } else if (_beginningDay - p.lastActionTimestamp >= 14 days) {
            return (p.lastActionTimestamp, 0, 1, p.lastLootClaimable);
        }
    }

    function getWeekLootClaimedDatas(address _user, uint256 _weekNumber)
        external
        view
        returns (bool claimable, bool claimed)
    {
        return _getWeekLootClaimedDatas(_user, _weekNumber);
    }

    function _getWeekLootClaimedDatas(address _user, uint256 _weekNumber)
        internal
        view
        returns (bool claimable, bool claimed)
    {
        Progress storage p = _progress[_user];
        return (
            p.weeklyLootClaimed[_weekNumber].claimable,
            p.weeklyLootClaimed[_weekNumber].claimed
        );
    }

    function _getDayBegining() internal view returns (uint256) {
        return IRank.getDayBegining();
    }

    // UPDATE AUDIT : return beginingDay allow to get it in _updateCounterWinLoss in fight contract
    function updateUserProgress(address _user)
        external
        onlyGame
        returns (uint256 beginingDay)
    {
        Progress storage p = _progress[_user];
        beginingDay = _getDayBegining();
        if (p.lastActionTimestamp == 0) {
            p.lastActionTimestamp = block.timestamp;
            p.dayOfWeek = 1;
            p.weekNumber = 1;
        } else {
            if (beginingDay >= p.lastActionTimestamp) {
                if (beginingDay - p.lastActionTimestamp <= 1 days) {
                    p.lastActionTimestamp = block.timestamp;
                    ++p.dayOfWeek;
                    if (p.dayOfWeek == 8) {
                        if (p.lastLootClaimable < p.weekNumber) {
                            p.weeklyLootClaimed[p.weekNumber].claimable = true;
                            p.lastLootClaimable = p.weekNumber;
                        }
                        ++p.weekNumber;
                        p.dayOfWeek = 1;
                    }
                } else {
                    p.dayOfWeek = 1;
                    if (
                        beginingDay - p.lastActionTimestamp > 7 days &&
                        beginingDay - p.lastActionTimestamp < 14 days
                    ) {
                        if (p.weekNumber > 1) {
                            --p.weekNumber;
                        }
                    } else if (beginingDay - p.lastActionTimestamp >= 14 days) {
                        p.weekNumber = 1;
                    }
                    p.lastActionTimestamp = block.timestamp;
                }
            }
        }
    }

    function claimLoot(uint256 _weekNumber) external {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");
        Progress storage p = _progress[msg.sender];

        require(
            p.weeklyLootClaimed[_weekNumber].claimable &&
                !p.weeklyLootClaimed[_weekNumber].claimed,
            "Reward not available"
        );
        if (_weekNumber > 1) {
            require(
                p.weeklyLootClaimed[_weekNumber - 1].claimed,
                "Previous week loot hasn't been claimed"
            );
        }
        p.weeklyLootClaimed[_weekNumber].claimable = false;
        p.weeklyLootClaimed[_weekNumber].claimed = true;

        uint256[4] memory _loot;

        if (_weekNumber % 10 == 0) {
            uint256 _eggLoot = _getEggsLoot(msg.sender, true);
            _loot[0] = (_eggLoot);
            emit NewLootResult(msg.sender, 1, _loot);
        } else if (_weekNumber % 5 == 0) {
            uint256 _eggLoot = _getEggsLoot(msg.sender, false);
            _loot[0] = (_eggLoot);
            emit NewLootResult(msg.sender, 1, _loot);
        } else {
            uint256 _tens = _weekNumber / 10;

            uint256 _nbOfPotions = _tens + (_weekNumber < 5 ? 1 : 2);
            uint256 _minLevel = _weekNumber + (_tens == 0 ? 5 : _tens * 15);
            _loot = _getPotionLoot(
                msg.sender,
                // limit to 4 potions
                _nbOfPotions > 4 ? 4 : _nbOfPotions,
                _minLevel,
                _minLevel * 2
            );
            emit NewLootResult(msg.sender, 0, _loot);
        }
    }

    // UPDATE AUDIT : check if daily loot can be claim
    function canClaimDailyLoot(address _user) external view returns (bool) {
        (uint256 _day, ) = IRank.getDayAndWeekRankingCounter();
        if (
            _progress[_user].lastActionTimestamp >= _getDayBegining() &&
            !_dailyLootClaimed[_day][_user]
        ) {
            return true;
        } else {
            return false;
        }
    }

    // UPDATE AUDIT : claim daily loot
    function claimDailyLoot() external {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");
        (uint256 _day, ) = IRank.getDayAndWeekRankingCounter();
        require(
            _progress[msg.sender].lastActionTimestamp >= _getDayBegining(),
            "User doesn't played today"
        );
        require(
            !_dailyLootClaimed[_day][msg.sender],
            "Daily loot already claimed today"
        );
        _dailyLootClaimed[_day][msg.sender] = true;

        emit DailyLootClaimed(
            msg.sender,
            Potions.offerPotion(_day % 5, 2, msg.sender)
        );
    }

    function _getPotionLoot(
        address _user,
        uint256 _numberOfPotions,
        uint256 _minLevel,
        uint256 _maxLevel
    ) internal returns (uint256[4] memory potions) {
        uint256[8] memory r = _generateRandomDatas();
        uint256[4] memory _potions;
        //UPDATE AUDIT : cap potion to 200pts max and 50 min
        _maxLevel = _maxLevel > 200 ? 200 : _maxLevel;
        _minLevel = _minLevel > 50 ? 50 : _minLevel;

        for (uint256 i; i < _numberOfPotions; ) {
            //UPDATE AUDIT : delete (-1)
            uint256 _power = _minLevel + (r[i] % (_maxLevel - _minLevel));
            uint256 _potionType = r[i] % 5;

            _potions[i] = Potions.offerPotion(_potionType, _power, _user);
            unchecked {
                ++i;
            }
        }
        return _potions;
    }

    // _tensRandom true allows to random a gold or a platinum
    function _getEggsLoot(address _user, bool _tensRandom)
        internal
        returns (uint256 egg)
    {
        uint256[8] memory r = _generateRandomDatas();
        uint256 _state = r[0] % 3;
        if (_tensRandom) {
            ++_state;
        }

        return Eggs.mintEgg(_user, _state, 0);
    }

    // utils

    function _generateRandomDatas() private returns (uint256[8] memory) {
        uint256 r = Oracle.getRandom();

        uint256[8] memory randoms;
        uint256 _mult = 1000;
        for (uint256 i; i < 7; ) {
            randoms[i] = uint256(r / _mult);
            _mult = _mult * 100;
            unchecked {
                ++i;
            }
        }
        return (randoms);
    }
}
