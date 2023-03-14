// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library ZaiStruct {
    // Zai powers
    struct Powers {
        uint8 water;
        uint8 fire;
        uint8 metal;
        uint8 air;
        uint8 stone;
    }

    // A zai can work in a center , training or coaching. He can't fight if he isn't free
    //string[4] _status = ["Free","Training","Coaching","Working"];
    // UPDATE AUDIT : add spotId
    struct Activity {
        uint8 statusId;
        uint8 onSpotId;
        uint16 onCenter;
    }

    struct ZaiMetaData {
        uint8 state; // _states index
        uint8 seasonOf;
        uint32 ipfsPathId;
        bool isGod;
    }

    struct Zai {
        uint8 level;
        uint8 creditForUpgrade; // credit to use to raise powers
        uint16 manaMax;
        uint16 mana;
        uint32 xp;
        Powers powers;
        Activity activity;
        ZaiMetaData metadata;
        string name;
    }

    struct ZaiMinDatasForFight {
        uint8 level;
        uint8 state;
        uint8 statusId;
        uint8 water;
        uint8 fire;
        uint8 metal;
        uint8 air;
        uint8 stone;
    }

    struct EggsPrices {
        uint256 bronzePrice;
        uint256 silverPrice;
        uint256 goldPrice;
        uint256 platinumPrice;
    }

    struct MintedData {
        uint256 bronzeMinted;
        uint256 silverMinted;
        uint256 goldMinted;
        uint256 platinumMinted;
    }

    struct WorkInstance {
        uint256 zaiId;
        uint256 beginingAt;
    }

    struct DelegateData {
        address scholarAddress;
        address ownerAddress;
        uint8 percentageForScholar;
        uint32 contractDuration;
        uint32 contractEnd;
        uint32 lastScholarPlayed;
        bool renewable;
    }

    struct GuildeDatas {
        address renterOf;
        address masterOf;
        address platformAddress;
        uint8 percentageForScholar;
        uint8 percentageForGuilde;
        uint8 percentagePlatformFees;
    }

    struct ScholarDatas {
        GuildeDatas guildeDatas;
        DelegateData delegateDatas;
    }
}

library PotionStruct {
    struct Powers {
        uint8 water;
        uint8 fire;
        uint8 metal;
        uint8 air;
        uint8 stone;
        uint8 rest;
        uint8 xp;
        uint8 mana;
    }

    struct Potion {
        address seller;
        uint256 listingPrice;
        uint256 fromLab;
        uint256 potionId;
        uint256 saleTimestamp;
        uint8 potionType; // 0: water ; 1: fire ; 2:metal ; 3:air ; 4:stone  ; 5:rest ; 6:xp ; 7:multiple ; 99 : empty
        Powers powers;
    }
}

library LaboStruct {
    struct WorkInstance {
        uint256 zaiId;
        uint256 beginingAt;
    }

    struct LabDetails {
        uint256 revenues;
        uint256 employees;
        uint256 potionsCredits;
        uint256 numberOfSpots;
        WorkInstance[10] workingSpot;
    }
}

library TrainingStruct {
    // UPDATE AUDIT : stats in struct
    struct Stats {
        uint256 trainingNumber;
        uint256 coachingNumber;
    }

    struct CoachDatas {
        bool coachRequired;
        uint256 minLevelReq;
        uint256 currentCoachLevel;
        uint256 percentPayment;
        uint256 coachId;
    }

    struct TrainingInstance {
        bool spotOpened;
        uint256 price;
        uint256 duration;
        uint256 endAt;
        uint256 zaiId;
        CoachDatas coach;
    }

    struct TrainingDetails {
        uint256 revenues;
        uint256 numberOfSpots;
        TrainingInstance[10] trainingSpots;
    }
}

library AddressesInit {
    enum Addresses {
        ALCHEMY,
        BZAI_TOKEN,
        CHICKEN,
        CLAIM_NFTS,
        DELEGATE,
        EGGS_NFT,
        FIGHT,
        FIGHT_PVP,
        IPFS_STORAGE,
        LABO_MANAGEMENT,
        LABO_NFT,
        LEVEL_STORAGE,
        LOOT,
        MARKET_PLACE,
        MARKET_DUTCH_AUCTION_ZAI,
        NURSERY_MANAGEMENT,
        NURSERY_NFT,
        OPEN_AND_CLOSE,
        ORACLE,
        PAYMENTS,
        POTIONS_NFT,
        PVP_GAME,
        RANKING,
        RENT_MY_NFT,
        REWARDS_PVP,
        REWARDS_WINNING_PVE,
        REWARDS_RANKING,
        TRAINING_MANAGEMENT,
        TRAINING_NFT,
        ZAI_META,
        ZAI_NFT
    }

    //     ALCHEMY, 0
    //     BZAI_TOKEN, 1
    //     CHICKEN, 2
    //     CLAIM_NFTS, 3
    //     DELEGATE, 4
    //     EGGS_NFT, 5
    //     FIGHT, 6
    //     FIGHT_PVP, 7
    //     IPFS_STORAGE, 8
    //     LABO_MANAGEMENT, 9
    //     LABO_NFT, 10
    //     LEVEL_STORAGE, 11
    //     LOOT, 12
    //     MARKET_PLACE, 13
    //     MARKET_DUTCH_AUCTION_ZAI, 14
    //     NURSERY_MANAGEMENT, 15
    //     NURSERY_NFT, 16
    //     OPEN_AND_CLOSE, 17
    //     ORACLE, 18
    //     PAYMENTS, 19
    //     POTIONS_NFT, 20
    //     PVP_GAME, 21
    //     RANKING, 22
    //     RENT_MY_NFT, 23
    //     REWARDS_PVP, 24
    //     REWARDS_WINNING_PVE, 25
    //     REWARDS_RANKING, 26
    //     TRAINING_MANAGEMENT, 27
    //     TRAINING_NFT, 28
    //     ZAI_META, 29
    //     ZAI_NFT, 30
}

interface IAddresses {
    function isAuthToManagedNFTs(address _address) external view returns (bool);

    function isAuthToManagedPayments(address _address)
        external
        view
        returns (bool);

    function getAddressOf(AddressesInit.Addresses _contract)
        external
        view
        returns (address);
}

interface IAlchemy {
    function updateInterfaces() external;
}

interface IBZAI is IERC20 {
    function burn(uint256 _amount) external returns (bool);
}

interface IChicken is IERC721 {
    function mintChicken(address _to) external returns (uint256);
}

interface IDelegate {
    function gotDelegationForZai(uint256 _zaiId)
        external
        view
        returns (ZaiStruct.ScholarDatas memory scholarDatas);

    function canUseZai(uint256 _zaiId, address _user)
        external
        view
        returns (bool);

    function getDelegateDatasByZai(uint256 _zaiId)
        external
        view
        returns (ZaiStruct.DelegateData memory);

    function isZaiDelegated(uint256 _zaiId) external view returns (bool);

    function updateLastScholarPlayed(uint256 _zaiId) external returns (bool);

    function updateInterfaces() external;
}

interface IEggs is IERC721 {
    function mintEgg(
        address _to,
        uint256 _state,
        uint256 _maturityDuration
    ) external returns (uint256);
}

interface IFighting {
    function updateInterfaces() external;
}

interface IFightingLibrary {
    function updateFightingProgress(
        uint256[30] memory _toReturn,
        uint256[9] calldata _elements,
        uint256[9] calldata _powers
    ) external pure returns (uint256[30] memory);

    function getUsedPowersByElement(
        uint256[9] calldata _elements,
        uint256[9] calldata _powers
    ) external pure returns (uint256[5] memory);

    function isPowersUsedCorrect(
        uint8[5] calldata _got,
        uint256[5] calldata _used
    ) external pure returns (bool);

    function getNewPattern(
        uint256 _random,
        ZaiStruct.ZaiMinDatasForFight memory c,
        uint256[30] memory _toReturn
    ) external pure returns (uint256[30] memory result);
}

interface IGuildeDelegation {
    struct GuildeDatas {
        address renterOf;
        address masterOf;
        address platformAddress;
        uint8 percentageForScholar;
        uint8 percentageForGuilde;
        uint8 percentagePlatformFees;
    }

    function getRentingDatas(address _nftAddress, uint256 _tokenId)
        external
        view
        returns (ZaiStruct.GuildeDatas memory);
}

interface IipfsIdStorage {
    function getTokenURI(
        uint256 _season,
        uint256 _state,
        uint256 _id
    ) external view returns (string memory);

    function getNextIpfsId(uint256 _state, uint256 _nftId)
        external
        returns (uint256);

    function getCurrentSeason() external view returns (uint8);

    function updateInterfaces() external;
}

interface ILaboratory is IERC721 {
    function mintLaboratory(address _to) external returns (uint256);

    function burn(uint256 _tokenId) external;

    function getCreditLastUpdate(uint256 _tokenId)
        external
        view
        returns (uint256);

    function updateCreditLastUpdate(uint256 _tokenId) external returns (bool);

    function numberOfWorkingSpots(uint256 _tokenId)
        external
        view
        returns (uint256);

    function updateNumberOfWorkingSpots(uint256 _tokenId, uint256 _quantity)
        external
        returns (bool);

    function getPreMintNumber() external view returns (uint256);

    function updateInterfaces() external;
}

interface ILabManagement {
    function initSpotsNumber(uint256 _tokenId) external returns (bool);

    function cleanSlotsBeforeClosing(uint256 _laboId) external returns (bool);

    function updateInterfaces() external;
}

interface ILevelStorage {
    function addFighter(uint256 _level, uint256 _zaiId) external returns (bool);

    function removeFighter(uint256 _level, uint256 _zaiId)
        external
        returns (bool);

    function getLevelLength(uint256 _level) external view returns (uint256);

    function getRandomZaiFromLevel(
        uint256 _level,
        uint256 _idForbiden,
        uint256 _random
    ) external view returns (uint256);

    function updateInterfaces() external;
}

interface ILootProgress {
    // UPDATE AUDIT : update interface
    function updateUserProgress(address _user)
        external
        returns (uint256 beginingDay);

    function updateInterfaces() external;
}

interface IMarket {
    function updateInterfaces() external;
}

interface INurseryNFT is IERC721 {
    function totalSupply() external view returns (uint256);
}

interface INurseryManagement {
    function getEggsPrices(uint256 _nursId)
        external
        view
        returns (ZaiStruct.EggsPrices memory);

    function updateInterfaces() external;
}

interface IOpenAndClose {
    function getLaboCreatingTime(uint256 _tokenId)
        external
        view
        returns (uint256);

    function canLaboSell(uint256 _tokenId) external view returns (bool);

    function canTrain(uint256 _tokenId) external view returns (bool);

    function updateInterfaces() external;
}

interface IOracle {
    function getRandom() external returns (uint256);
}

interface IPayments {
    function payOwner(address _owner, uint256 _value) external returns (bool);

    function getAvailable(address _user) external view returns (uint256);

    function distributeFees(uint256 _amount) external returns (bool);

    function burnUndistributedRewards(uint256 _amount) external returns (bool);

    function rewardPlayer(
        address _user,
        uint256 _amount,
        uint256 _zaiId,
        uint256 _state,
        bool _isDelegate
    ) external returns (bool);

    function burnRevenuesForEggs(address _owner, uint256 _amount)
        external
        returns (bool);

    function payNFTOwner(address _owner, uint256 _amount)
        external
        returns (bool);

    function payWithRewardOrWallet(address _user, uint256 _amount)
        external
        returns (bool);
}

interface IPotions is IERC721 {
    function mintPotionForSale(
        uint256 _laboId,
        uint256 _price,
        uint256 _type,
        uint256 _power,
        uint256 _quantity
    ) external returns (uint256[] memory);

    function offerPotion(
        uint256 _type,
        uint256 _power,
        address _to
    ) external returns (uint256);

    function burnPotion(uint256 _tokenId) external returns (bool);

    function emptyingPotion(uint256 _tokenId) external returns (bool);

    function mintMultiplePotion(uint256[7] memory _powers, address _owner)
        external
        returns (uint256);

    function changePotionPrice(
        uint256 _tokenId,
        uint256 _laboId,
        uint256 _price
    ) external returns (bool);

    function updatePotionSaleTimestamp(uint256 _tokenId)
        external
        returns (bool);

    function getFullPotion(uint256 _tokenId)
        external
        view
        returns (PotionStruct.Potion memory);

    function getPotionPowers(uint256 _tokenId)
        external
        view
        returns (PotionStruct.Powers memory);

    function updateInterfaces() external;
}

interface IRanking {
    function updatePlayerRankings(address _user, uint256 _xpWin)
        external
        returns (bool);

    function getDayBegining() external view returns (uint256);

    function getDayAndWeekRankingCounter()
        external
        view
        returns (uint256 dayNumber, uint256 weekNumber);

    function updateInterfaces() external;
}

interface IReserveForChalengeRewards {
    function updateRewards() external returns (bool, uint256);
}

interface IReserveForWinRewards {
    function updateRewards() external returns (bool, uint256);
}

interface IRewardsPvP {
    function updateInterfaces() external;
}

interface IRewardsRankingFound {
    function getDailyRewards(address _rewardStoringAddress)
        external
        returns (uint256);

    function getWeeklyRewards(address _rewardStoringAddress)
        external
        returns (uint256);

    function updateInterfaces() external;
}

interface IRewardsWinningFound {
    function getWinningRewards(uint256 level, bool bonus)
        external
        returns (uint256);

    function updateInterfaces() external;
}

interface ITraining is IERC721 {
    function mintTrainingCenter(address _to) external returns (uint256);

    function burn(uint256 _tokenId) external;

    function numberOfTrainingSpots(uint256 _tokenId)
        external
        view
        returns (uint256);

    function addTrainingSpots(uint256 _tokenId, uint256 _amount)
        external
        returns (bool);

    function getPreMintNumber() external view returns (uint256);

    function updateInterfaces() external;
}

interface ITrainingManagement {
    function initSpotsNumber(uint256 _tokenId) external returns (bool);

    function cleanSlotsBeforeClosing(uint256 _laboId) external returns (bool);

    function updateInterfaces() external;
}

interface IZaiNFT is IERC721 {
    function mintZai(
        address _to,
        string memory _name,
        uint256 _state
    ) external returns (uint256);

    function createNewChallenger() external returns (uint256);

    function burnZai(uint256 _tokenId) external returns (bool);
}

interface IZaiMeta {
    function getZaiURI(uint256 tokenId) external view returns (string memory);

    function createZaiDatas(
        uint256 _newItemId,
        string memory _name,
        uint256 _state,
        uint256 _level
    ) external;

    function getZai(uint256 _tokenId)
        external
        view
        returns (ZaiStruct.Zai memory);

    function getZaiMinDatasForFight(uint256 _tokenId)
        external
        view
        returns (ZaiStruct.ZaiMinDatasForFight memory zaiMinDatas);

    function isFree(uint256 _tokenId) external view returns (bool);

    function updateStatus(
        uint256 _tokenId,
        uint256 _newStatusID,
        uint256 _center,
        uint256 _spotId
    ) external;

    function updateXp(uint256 _id, uint256 _xp)
        external
        returns (uint256 level);

    function updateMana(
        uint256 _tokenId,
        uint256 _manaUp,
        uint256 _manaDown,
        uint256 _maxUp
    ) external returns (bool);

    function getNextLevelUpPoints(uint256 _level)
        external
        view
        returns (uint256);

    function updateInterfaces() external;
}
