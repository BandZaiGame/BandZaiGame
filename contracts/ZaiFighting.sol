// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// Zai fighting contract for PvE game
// player will give a strategy to his Zai and environment will found a challenger from the same level and create a strategy for him
// player can use potion xp to multiply xp reward and potion with element power to take advantage in fight
// The is a stamina of 5 max (number of fight the Zai can make)
// Stamina is automatic regenerated with time but faster with a Zai state rarity
// Fight will automaticly create and update ranking (xp won) each day and week
// Fight will check delegate data (scholarship)
// fight will give BZAI rewards if zai win the fight (with a limit quantity by day depending on zai state rarity)
contract ZaiFighting is Ownable {
    IAddresses public gameAddresses;
    IZaiMeta public IMeta;
    IDelegate public IDel;
    IPotions public Potions;
    IRanking public IRank;
    ILootProgress public ILoot;
    ILevelStorage public ILevel;
    IPayments public IPay;
    IFightingLibrary public IFightLib;
    IRewardsWinningFound public IRewards;
    IOracle public Oracle;

    bool public inPause;

    uint256[4] public staminaRegenerationDuration = [16200, 14400, 10800, 5400]; // in seconds (bronze 4h30 / silver 4h / gold 3h / platinum 1h30 )
    // UPDATE AUDIT : platinum got 50
    uint256[4] public bzaiRewardCountPerDay = [3, 8, 15, 50]; // Number of fight by day where Zai can get BZAI rewards
    // UPDATE AUDIT : 2000 => 4000 (game xp balance update)
    uint256 public xpRewardByFight = 4000;

    mapping(uint256 => uint256) _zaiStamina;
    mapping(uint256 => uint256) _firstOf5FightTimestamp;

    mapping(uint256 => uint256) _lastWinTimestamp;
    mapping(uint256 => uint256) _dayWinCounter;

    event FightResult(
        address indexed player,
        uint256 indexed zaiId,
        uint256[30] progress,
        uint256[9] elements,
        uint256[9] powers
    );
    // UPDATE AUDIT : RewardFightWon => RewardWon is in payment contract now

    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address zaiNFT,
        address delegate,
        address potions,
        address ranking,
        address loot,
        address level,
        address payments,
        address rewards,
        address oracle
    );
    event PauseActivated(bool isOnPause);
    event XpRewardUpdated(uint256 previousValue, uint256 newValue);
    event BzaiRewardCountPerDayUpdated(
        uint256[4] previousDatas,
        uint256[4] newDatas
    );
    event RegenerationDurationUpdated(
        uint256[4] previousDatas,
        uint256[4] newDatas
    );
    event RestPotionUsed(address user, uint256 indexed zaiId, uint256 potionId);

    constructor(address _library) {
        IFightLib = IFightingLibrary(_library);
    }

    function setGameAddresses(address _address) external onlyOwner {
        require(gameAddresses == IAddresses(address(0x0)), "Already setted");
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function updateInterfaces() external {
        IMeta = IZaiMeta(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_META)
        );
        IDel = IDelegate(
            gameAddresses.getAddressOf(AddressesInit.Addresses.DELEGATE)
        );
        Potions = IPotions(
            gameAddresses.getAddressOf(AddressesInit.Addresses.POTIONS_NFT)
        );
        ILoot = ILootProgress(
            gameAddresses.getAddressOf(AddressesInit.Addresses.LOOT)
        );
        ILevel = ILevelStorage(
            gameAddresses.getAddressOf(AddressesInit.Addresses.LEVEL_STORAGE)
        );
        IPay = IPayments(
            gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
        );
        IRank = IRanking(
            gameAddresses.getAddressOf(AddressesInit.Addresses.RANKING)
        );
        IRewards = IRewardsWinningFound(
            gameAddresses.getAddressOf(
                AddressesInit.Addresses.REWARDS_WINNING_PVE
            )
        );
        Oracle = IOracle(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ORACLE)
        );
        emit InterfacesUpdated(
            address(IMeta),
            address(IDel),
            address(Potions),
            address(IRank),
            address(ILoot),
            address(ILevel),
            address(IPay),
            address(IRewards),
            address(Oracle)
        );
    }

    function pauseUnpauseGame() external onlyOwner {
        inPause = !inPause;
        emit PauseActivated(inPause);
    }

    // For some events there will be more xp available to win
    function setXpRewardByFight(uint256 _xp) external onlyOwner {
        uint256 _previousValue = xpRewardByFight;
        xpRewardByFight = _xp;
        emit XpRewardUpdated(_previousValue, _xp);
    }

    // For some events Zai will be allow to win more or
    function setBzaiRewardCountPerDay(uint256[4] memory _nbOfFight)
        external
        onlyOwner
    {
        uint256[4] memory _previousDatas = bzaiRewardCountPerDay;
        bzaiRewardCountPerDay = _nbOfFight;
        emit BzaiRewardCountPerDayUpdated(_previousDatas, _nbOfFight);
    }

    // For some events Zai will be allow to make more fight without necessity to regenerate
    function setRegenerationDuration(uint256[4] memory _durations)
        external
        onlyOwner
    {
        uint256[4] memory _previousDatas = staminaRegenerationDuration;
        staminaRegenerationDuration = _durations;
        emit RegenerationDurationUpdated(_previousDatas, _durations);
    }

    function getDayWinByZai(uint256 zaiId) external view returns (uint256) {
        if (_lastWinTimestamp[zaiId] > IRank.getDayBegining()) {
            return _dayWinCounter[zaiId];
        } else {
            return 0;
        }
    }

    // UPDATE AUDIT : return next fight unlocking timestamp for front end
    function getZaiStamina(uint256 _zaiId)
        external
        view
        returns (uint256 result, uint256 nextUnlockingFight)
    {
        ZaiStruct.ZaiMinDatasForFight memory z = IMeta.getZaiMinDatasForFight(
            _zaiId
        );
        (result, ) = _getZaiStamina(_zaiId, z);
        nextUnlockingFight =
            _firstOf5FightTimestamp[_zaiId] +
            staminaRegenerationDuration[z.state];
    }

    function _getZaiStamina(
        uint256 _zaiId,
        ZaiStruct.ZaiMinDatasForFight memory z
    ) internal view returns (uint256 stamina, uint256 added) {
        // if no fight return max stamina : 5
        if (_firstOf5FightTimestamp[_zaiId] == 0) {
            stamina = 5;
        } else {
            unchecked {
                // take the old variable
                stamina = _zaiStamina[_zaiId];
                // calculate time passed since the first of 5 last fights
                uint256 _timeSinceLastFight = block.timestamp -
                    _firstOf5FightTimestamp[_zaiId];
                // if there is > 1 stamina duration
                if (
                    _timeSinceLastFight >= staminaRegenerationDuration[z.state]
                ) {
                    // calculate number of stamina to add no need modulo cause in solidity 100 / 60 = 1
                    added =
                        _timeSinceLastFight /
                        staminaRegenerationDuration[z.state];
                    // max stamina is 5
                    if (stamina + added >= 5) {
                        stamina = 5;
                    } else {
                        stamina += added;
                    }
                }
            }
        }
    }

    function _updateStamina(
        uint256 _zaiId,
        ZaiStruct.ZaiMinDatasForFight memory z
    ) internal returns (bool) {
        //reload
        (uint256 stamina, uint256 added) = _getZaiStamina(_zaiId, z);
        _zaiStamina[_zaiId] = stamina;
        require(_zaiStamina[_zaiId] != 0, "exhausted Zai!");

        unchecked {
            if (stamina == 5) {
                _firstOf5FightTimestamp[_zaiId] = block.timestamp;
            } else {
                _firstOf5FightTimestamp[_zaiId] += (added *
                    staminaRegenerationDuration[z.state]);
            }
            // reduce stamina counter
            --_zaiStamina[_zaiId]; //
        }
        return true;
    }

    function useRestPotion(uint256 _zaiId, uint256 _potionId) external {
        require(
            IDel.canUseZai(_zaiId, msg.sender),
            "Not your zai nor delegated"
        );

        require(Potions.ownerOf(_potionId) == msg.sender);
        ZaiStruct.ZaiMinDatasForFight memory z = IMeta.getZaiMinDatasForFight(
            _zaiId
        );
        (uint256 stamina, ) = _getZaiStamina(_zaiId, z);
        if (stamina >= 2) {
            revert("Zai doesn't need rest portion");
        }
        // UPDATE AUDIT : delete this option
        // rest for training
        PotionStruct.Powers memory p = Potions.getPotionPowers(_potionId);
        require(p.rest != 0, "Not a rest p");
        Potions.emptyingPotion(_potionId);
        _zaiStamina[_zaiId] = 5;
        emit RestPotionUsed(msg.sender, _zaiId, _potionId);
    }

    // _elements (0: water ; 1: fire ; 2:metal ; 3:air ; 4:stone)
    // UPDATE AUDIT : replace uint256[9] memory by calldata
    // UPDATE AUDIT : no need to returns uint256[30] memory
    function initFighting(
        uint256 _zaiId,
        uint256[9] calldata _elements,
        uint256[9] calldata _powers,
        uint256[] calldata _usedPotions
    ) external {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");
        // UPDATE AUDIT : check max potion number
        require(_usedPotions.length <= 3, "Max 3 potions by fight");
        require(!inPause, "Game is in pause");
        // store delegationDatas for this Zai
        ZaiStruct.ScholarDatas memory scholarDatas = IDel.gotDelegationForZai(
            _zaiId
        );

        // If Zai is in delegation process, Zai can't be used by his owner
        if (scholarDatas.delegateDatas.ownerAddress == msg.sender) {
            require(
                scholarDatas.delegateDatas.scholarAddress == address(0x0),
                "You delegated your Zai"
            );
        }

        // check if zai can be use by msg.sender (owner or got delegation)
        // UPDATE AUDIT : add check contractend not passed
        require(
            scholarDatas.delegateDatas.ownerAddress == msg.sender ||
                (scholarDatas.delegateDatas.scholarAddress == msg.sender &&
                    scholarDatas.delegateDatas.contractEnd >=
                    block.timestamp) ||
                scholarDatas.guildeDatas.renterOf == msg.sender,
            "Not your zai nor delegated"
        );

        // store Zai NFT datas
        ZaiStruct.ZaiMinDatasForFight memory z = IMeta.getZaiMinDatasForFight(
            _zaiId
        );
        // check if Zai is not in training, working or coaching. Must be free
        require(z.statusId == 0, "Not free");
        // update stamin of Zai
        require(_updateStamina(_zaiId, z), "Stamina error");

        // UPDATE AUDIT : updateUserProgress return the beginning day avoiding call this more than 1 time
        // update loot progress (weekly reward when you play all days)
        uint256 _dayBegining = ILoot.updateUserProgress(msg.sender);

        // UPDATE AUDIT : checking potions is done in _getZaiPowersByElement

        // check if user respect number of powers rule ( don't use more than Zai can use with potions or not)
        (uint8[5] memory _gotPowers, uint256 _xpMult) = _getZaiPowersByElement(
            z,
            _usedPotions
        );

        require(
            IFightLib.isPowersUsedCorrect(
                _gotPowers,
                IFightLib.getUsedPowersByElement(_elements, _powers)
            ),
            "cheat!"
        );

        // create randoms
        uint256 _random = Oracle.getRandom();

        // UPDATE AUDIT : init uint256[30] result here
        uint256[30] memory result; //[0: obsolete,1:myScore, 2:challengerScore, 3-11: ElementByRoundOfChallenger, 12-20: PowerUseByChallengerByRound, 21 number of potions used by challenger, 22-23-24 type of potions if relevent, 25-26-27 power of potions if relevent, 28 xpWon, 29 BZAI won ]

        // UPDATE AUDIT : random is sent to ILevel avoiding calling 2 times random function
        // get a challenger (can't be the same Zai used by the user)
        result[0] = ILevel.getRandomZaiFromLevel(z.level, _zaiId, _random);

        // store in memory challenger Zai NFT Datas
        ZaiStruct.ZaiMinDatasForFight memory c = IMeta.getZaiMinDatasForFight(
            result[0]
        );

        // create challenger pattern
        result = IFightLib.getNewPattern(_random, c, result);

        // update the fighting progress in the return array
        result = IFightLib.updateFightingProgress(result, _elements, _powers);

        // update all counters
        result[28] = _getXpToWin(_powers, _gotPowers, _xpMult);
        result = _updateCounterWinLoss(
            z,
            _zaiId,
            result,
            scholarDatas,
            _xpMult,
            _dayBegining
        );

        // create event of fight
        emit FightResult(msg.sender, _zaiId, result, _elements, _powers);
    }

    // UPDATE AUDIT : replace uint256[] memory by calldata
    function _getXpToWin(
        uint256[9] calldata _powers,
        uint8[5] memory _gotPowers,
        uint256 _xpMult
    ) internal view returns (uint256 _xp) {
        unchecked {
            uint256 _totalPowers = _gotPowers[0] +
                _gotPowers[1] +
                _gotPowers[2] +
                _gotPowers[3] +
                _gotPowers[4];
            uint256 _totalUsedPowers;
            for (uint256 i; i < 9; ) {
                _totalUsedPowers += _powers[i];

                ++i;
            }
            // minimum xp to win is xpRewardByFight / 2 => we use * 100 for more precision
            _xp = (xpRewardByFight * 100) / 2;
            // calculate xp :
            // max xp - (half max xp / ratio powers used vs power got) / 100 for more precision
            _xp = ((2 * _xp) - ((_xp * _totalUsedPowers) / _totalPowers)) / 100;

            if (_xpMult > 1) {
                _xp *= _xpMult;
            }
        }
    }

    // UPDATE AUDIT : add dayBegining
    function _updateCounterWinLoss(
        ZaiStruct.ZaiMinDatasForFight memory z,
        uint256 _zaiId,
        uint256[30] memory _toReturn,
        ZaiStruct.ScholarDatas memory _scholarDatas,
        uint256 _xpMult,
        uint256 _dayBegining
    ) internal returns (uint256[30] memory) {
        // UPDATE AUDIT:delete stats updates
        uint256 _xpWon = xpRewardByFight / 10;
        uint256 _bzaiWon;
        if (_toReturn[1] < _toReturn[2]) {
            _toReturn[28] = _xpWon * _xpMult;
        } else if (_toReturn[1] == _toReturn[2]) {
            _toReturn[28] = _xpWon * 2 * _xpMult;
        } else {
            //Player win
            // UPDATE AUDIT : got _dayBegining now
            if (_lastWinTimestamp[_zaiId] < _dayBegining) {
                _dayWinCounter[_zaiId] = 1;
            } else {
                ++_dayWinCounter[_zaiId];
            }
            _lastWinTimestamp[_zaiId] = block.timestamp;
            if (_dayWinCounter[_zaiId] <= bzaiRewardCountPerDay[z.state]) {
                // get reward. there is a bonus when Zai got 2x score of challenger
                _bzaiWon = IRewards.getWinningRewards(
                    z.level,
                    (_toReturn[1] / 2 >= _toReturn[2])
                );
                if (
                    _scholarDatas.delegateDatas.scholarAddress !=
                    address(0x0) ||
                    _scholarDatas.guildeDatas.renterOf != address(0x0)
                ) {
                    _bzaiWon = _paySchoolarAndOwner(
                        _scholarDatas,
                        _zaiId,
                        _bzaiWon,
                        z.state
                    );
                } else {
                    require(
                        IPay.rewardPlayer(
                            _scholarDatas.delegateDatas.ownerAddress,
                            _bzaiWon,
                            _zaiId,
                            z.state,
                            false
                        )
                    );
                }
            }
        }
        if (IMeta.updateXp(_zaiId, _toReturn[28]) > z.level) {
            _zaiStamina[_zaiId] = 5;
        }

        // UPDATE AUDIT: update 200 => xpRewardByFight/10 && 400 => xpRewardByFight/5 && 1000 => 200 => xpRewardByFight/2
        require(
            IRank.updatePlayerRankings(
                msg.sender,
                _toReturn[1] < _toReturn[2]
                    ? xpRewardByFight / 10
                    : _toReturn[1] == _toReturn[2]
                    ? xpRewardByFight / 5
                    : xpRewardByFight / 2
            ),
            "Ranking error"
        );
        _toReturn[29] = _bzaiWon;

        return _toReturn;
    }

    function _paySchoolarAndOwner(
        ZaiStruct.ScholarDatas memory _scholarDatas,
        uint256 _zaiId,
        uint256 _reward,
        uint256 _state
    ) internal returns (uint256 _scholarReward) {
        uint256 _ownerReward;
        address _ownerAddress;
        address _scholarAddress;

        if (_scholarDatas.delegateDatas.scholarAddress != address(0x0)) {
            require(IDel.updateLastScholarPlayed(_zaiId));
            _ownerReward =
                (_reward *
                    (100 - _scholarDatas.delegateDatas.percentageForScholar)) /
                100;
            _scholarReward = _reward - _ownerReward;

            _scholarAddress = _scholarDatas.delegateDatas.scholarAddress;
            _ownerAddress = _scholarDatas.delegateDatas.ownerAddress;
        } else {
            require(
                _scholarDatas.guildeDatas.percentagePlatformFees +
                    _scholarDatas.guildeDatas.percentageForScholar +
                    _scholarDatas.guildeDatas.percentageForGuilde ==
                    100,
                "Percentage from RNFT Guilde doesn't match"
            );

            uint256 _platfromFees = (_reward *
                _scholarDatas.guildeDatas.percentagePlatformFees) / 100;

            _scholarReward =
                (_reward * _scholarDatas.guildeDatas.percentageForScholar) /
                100;
            _ownerReward = _reward - _platfromFees - _scholarReward;

            _scholarAddress = _scholarDatas.guildeDatas.renterOf;
            _ownerAddress = _scholarDatas.guildeDatas.masterOf;

            require(
                IPay.rewardPlayer(
                    _scholarDatas.guildeDatas.platformAddress,
                    _platfromFees,
                    0,
                    0,
                    true
                )
            );
        }

        require(
            IPay.rewardPlayer(_ownerAddress, _ownerReward, _zaiId, _state, true)
        );
        require(IPay.rewardPlayer(_scholarAddress, _scholarReward, 0, 0, true));
    }

    // UPDATE AUDIT : function isn't view
    function _getZaiPowersByElement(
        ZaiStruct.ZaiMinDatasForFight memory z,
        uint256[] memory _potions
    ) internal returns (uint8[5] memory _powers, uint256 _xpMult) {
        unchecked {
            _powers = [z.water, z.fire, z.metal, z.air, z.stone];
        }
        _xpMult = 1;

        for (uint256 i; i < _potions.length; ) {
            // UPDATE AUDIT : check if owner
            require(
                Potions.ownerOf(_potions[i]) == msg.sender,
                "Not your potion"
            );
            // UPDATE AUDIT : get only potion.powers for GAS fees optimization
            PotionStruct.Powers memory p = Potions.getPotionPowers(_potions[i]);

            if (p.water != 0) {
                _powers[0] += p.water;
            }
            if (p.fire != 0) {
                _powers[1] += p.fire;
            }
            if (p.metal != 0) {
                _powers[2] += p.metal;
            }
            if (p.air != 0) {
                _powers[3] += p.air;
            }
            if (p.stone != 0) {
                _powers[4] += p.stone;
            }
            if (p.xp != 0) {
                require(_xpMult == 1, "Only 1 xp potion by fight");
                _xpMult = p.xp;
            }
            // UPDATE AUDIT : emptying potion
            Potions.emptyingPotion(_potions[i]);
            unchecked {
                ++i;
            }
        }
    }
}
