// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./Interfaces.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Zai meta data
//
contract ZaiMeta is Ownable {
    address zaiContract;
    IZaiNFT public IZai;
    ILevelStorage public ILevel;
    IAddresses public gameAddresses;
    IipfsIdStorage public Iipfs;
    IOracle public Oracle;
    IDelegate public IDel;
    address public gameV2optionsAddress;

    uint256 constant FIVE_POWERS_MIN_LEVEL = 15;
    uint256 constant FOUR_POWERS_MIN_LEVEL = 10;
    uint256 constant THREE_POWERS_MIN_LEVEL = 5;

    mapping(uint256 => string[7]) _godNames;

    mapping(uint256 => ZaiStruct.Zai) _zai;

    event GameAddressesSetted(address gameAddresses);
    event ZaiNftSetted(address zaiAddress);
    event InterfacesUpdated(
        address ipfsStorage,
        address oracle,
        address delegate
    );
    event GameV2Setted(address gameV2);
    event GodNamesSetted(uint256 season, string[7] godsName);
    event ZaiStatusUpdated(
        uint256 indexed zaiId,
        uint256 status,
        uint256 onCenter,
        uint256 spotId
    );
    event ManaUpdated(
        uint256 indexed zaiId,
        uint256 manaUp,
        uint256 manaDown,
        uint256 manaMax
    );
    event ZaiLevelUp(uint256 zaiId, uint256 newLevel);
    event ZaiXpUp(uint256 zaiId, uint256 newXp);

    constructor(string[7] memory _names, address _levelStorage) {
        require(_levelStorage != address(0), "levelStorage can't be address(0");
        _godNames[1] = _names;
        ILevel = ILevelStorage(_levelStorage);
    }

    // in exchange of runes , owner of a Zai can reset elements point
    // will be managed in V2 game
    function resetZaiPowers(uint256 _zaiId, address _ownerOfZai) external {
        require(
            msg.sender == gameV2optionsAddress,
            "Not authorized to reset Zai"
        );
        require(IZai.ownerOf(_zaiId) == _ownerOfZai, "Wrong owner");
        ZaiStruct.Zai storage z = _zai[_zaiId];

        uint8 _totalPoints = z.powers.water +
            z.powers.fire +
            z.powers.metal +
            z.powers.air +
            z.powers.stone;

        z.powers = ZaiStruct.Powers(0, 0, 0, 0, 0);
        z.creditForUpgrade = _totalPoints;
    }

    // in exchange of runes , owner of a Zai can rename his Zai
    function renameZai(
        uint256 _zaiId,
        address _ownerOfZai,
        string memory _name
    ) external {
        require(
            msg.sender == gameV2optionsAddress,
            "Not authorized to reset Zai"
        );
        require(IZai.ownerOf(_zaiId) == _ownerOfZai, "Wrong owner");
        _zai[_zaiId].name = _name;
    }

    function setGameAddresses(address _address) external onlyOwner {
        require(gameAddresses == IAddresses(address(0x0)), "Already setted");
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function updateInterfaces() external {
        Iipfs = IipfsIdStorage(
            gameAddresses.getAddressOf(AddressesInit.Addresses.IPFS_STORAGE)
        );
        Oracle = IOracle(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ORACLE)
        );
        IDel = IDelegate(
            gameAddresses.getAddressOf(AddressesInit.Addresses.DELEGATE)
        );
        emit InterfacesUpdated(address(Iipfs), address(Oracle), address(IDel));
    }

    function setGameV2optionsAddress(address _address) external onlyOwner {
        gameV2optionsAddress = _address;
        emit GameV2Setted(_address);
    }

    function getZai(uint256 _tokenId)
        external
        view
        returns (ZaiStruct.Zai memory)
    {
        return _zai[_tokenId];
    }

    function getZaiMinDatasForFight(uint256 _tokenId)
        external
        view
        returns (ZaiStruct.ZaiMinDatasForFight memory zaiMinDatas)
    {
        ZaiStruct.Zai memory z = _zai[_tokenId];
        zaiMinDatas = ZaiStruct.ZaiMinDatasForFight(
            z.level,
            z.metadata.state,
            z.activity.statusId,
            z.powers.water,
            z.powers.fire,
            z.powers.metal,
            z.powers.air,
            z.powers.stone
        );
    }

    function getZaiURI(uint256 tokenId) external view returns (string memory) {
        ZaiStruct.Zai memory z = _zai[tokenId];
        return
            Iipfs.getTokenURI(
                z.metadata.seasonOf,
                z.metadata.state,
                z.metadata.ipfsPathId
            );
    }

    function setGodNames(string[7] memory _names, uint256 _season)
        external
        onlyOwner
    {
        _godNames[_season] = _names;
        emit GodNamesSetted(_season, _names);
    }

    function setZaiContract(address _zaiContract) external onlyOwner {
        require(zaiContract == address(0x0));
        zaiContract = _zaiContract;
        IZai = IZaiNFT(_zaiContract);
        emit ZaiNftSetted(_zaiContract);
    }

    modifier onlyZai() {
        require(msg.sender == zaiContract, "Not authorized1");
        _;
    }

    modifier onlyAuth() {
        require(
            gameAddresses.isAuthToManagedNFTs(msg.sender),
            "Not authorized to manage Zai Meta"
        );
        _;
    }

    function _getState(uint256 state) internal pure returns (string memory) {
        string[4] memory _states = ["Bronze", "Silver", "Gold", "Platinum"];
        return _states[state];
    }

    function getStatus(uint256 _tokenId)
        external
        view
        returns (uint256[2] memory)
    {
        return [
            uint256(_zai[_tokenId].activity.statusId),
            uint256(_zai[_tokenId].activity.onCenter)
        ];
    }

    function updateStatus(
        uint256 _tokenId,
        uint256 _newStatusID,
        uint256 _center,
        uint256 _spotId
    ) external onlyAuth {
        _zai[_tokenId].activity.statusId = uint8(_newStatusID);
        _zai[_tokenId].activity.onCenter = uint16(_center);
        _zai[_tokenId].activity.onSpotId = uint8(_spotId);
        emit ZaiStatusUpdated(_tokenId, _newStatusID, _center, _spotId);
    }

    function updateMana(
        uint256 _tokenId,
        uint256 _manaUp,
        uint256 _manaDown,
        uint256 _maxUp
    ) external onlyAuth returns (bool) {
        ZaiStruct.Zai storage z = _zai[_tokenId];
        if (_maxUp != 0) {
            if (z.manaMax + _maxUp > 10000) {
                z.manaMax = 10000;
            } else {
                z.manaMax += uint16(_maxUp);
            }
        }

        if (_manaUp != 0) {
            if (z.mana + _manaUp > z.manaMax) {
                z.mana = z.manaMax;
            } else {
                z.mana += uint16(_manaUp);
            }
        }

        if (_manaDown != 0) {
            require(_manaDown <= z.mana, "Zai don't have enough mana");
            z.mana -= uint16(_manaDown);
        }
        emit ManaUpdated(_tokenId, _manaUp, _manaDown, _maxUp);
        return true;
    }

    function getZaiState(uint256 _tokenId)
        external
        view
        returns (string memory)
    {
        return _getState(_zai[_tokenId].metadata.state);
    }

    function isFree(uint256 _tokenId) external view returns (bool) {
        return (_zai[_tokenId].activity.statusId == 0);
    }

    function _preMintZai(uint256 _level, uint256 _newItemId) internal {
        _createZaiDatas(_newItemId, "challenger", 0, _level);
        ZaiStruct.Zai storage z = _zai[_newItemId];

        z.level = uint8(_level);
        z.xp = uint32(_getNextLevelUpPoints(_level));
    }

    function createZaiDatas(
        uint256 _newItemId,
        string memory _name,
        uint256 _state,
        uint256 _level
    ) external onlyZai {
        _createZaiDatas(_newItemId, _name, _state, _level);
    }

    function _createZaiDatas(
        uint256 _newItemId,
        string memory _name,
        uint256 _state,
        uint256 _level
    ) internal {
        require(ILevel.addFighter(_level, _newItemId));

        ZaiStruct.Zai storage z = _zai[_newItemId];
        uint256 _ipfsId = Iipfs.getNextIpfsId(_state, _newItemId);
        z.metadata.ipfsPathId = uint32(_ipfsId);
        z.metadata.seasonOf = Iipfs.getCurrentSeason();

        z.metadata.state = uint8(_state);
        if (_state == 3 && _ipfsId <= 7) {
            // gods got 10 or 12 pts base
            z.name = _getGodNames(_ipfsId, z.metadata.seasonOf);
            z.powers = _getGodsPowers(_ipfsId);
            z.metadata.isGod = true;
        } else {
            // All zais are created with 8 powers points in a random distribution
            uint256 random = Oracle.getRandom();
            uint256 _points = (_level * 3) + 8;
            z.name = _name;
            z.powers = _getRandomPowers(_level, _points, random);
        }
    }

    // return new level
    function updateXp(uint256 _id, uint256 _xp)
        external
        onlyAuth
        returns (uint256 level)
    {
        ZaiStruct.Zai storage z = _zai[_id];
        z.xp += uint32(_xp);
        // update level
        level = _getLevel(z.xp);

        if (z.level < 50) {
            // UPDATE AUDIT: Add this condition because no need to check level > 50 (all Zai in level >= 50 can fight together cauz' got same number of points)
            if (ILevel.getLevelLength(level) < 10) {
                _preMintZai(level, IZai.createNewChallenger());
                _preMintZai(level, IZai.createNewChallenger());
                _preMintZai(level, IZai.createNewChallenger());
            }
        }

        if (level > z.level) {
            if (z.level < 50) {
                // UPDATE AUDIT: This condition has been moove up because math overflow when Zai level already in >= 50 , raising another level make crash tx
                // update new level
                // max element points is on level 50 : 3 x 50 + 8pts = 158pts
                uint256 _numberOfLevelUp = (level > 50 ? 50 : level) - z.level;
                // zai win 3 points by level raised
                z.creditForUpgrade = uint8(
                    z.creditForUpgrade + (_numberOfLevelUp * 3)
                );
                // zai update from level storage
                require(ILevel.removeFighter(z.level, _id));
                require(ILevel.addFighter((level > 50 ? 50 : level), _id));
            }
            z.level = uint8(level);
            // UPDATE AUDIT: add event when level up
            emit ZaiLevelUp(_id, level);
        }
        emit ZaiXpUp(_id, z.xp);
    }

    function updatePowers(
        uint256 _zaiId,
        uint8 _water,
        uint8 _fire,
        uint8 _metal,
        uint8 _air,
        uint8 _stone
    ) external {
        ZaiStruct.Zai storage z = _zai[_zaiId];
        require(
            IDel.canUseZai(_zaiId, msg.sender),
            "Not your zai nor delegated"
        );
        require(
            z.creditForUpgrade >= (_water + _fire + _metal + _air + _stone),
            "Not enough credit"
        );

        z.creditForUpgrade -= (_water + _fire + _metal + _air + _stone);
        z.powers = _updatePowers(
            z.level,
            z.powers,
            ZaiStruct.Powers(_water, _fire, _metal, _air, _stone),
            z.metadata.isGod
        );
    }

    function _getGodNames(uint256 _ipfsId, uint256 _season)
        internal
        view
        returns (string memory)
    {
        return _godNames[_season][_ipfsId - 1];
    }

    function _getRandomPowers(
        uint256 level,
        uint256 _points,
        uint256 random
    ) internal pure returns (ZaiStruct.Powers memory) {
        uint256 _random = random;
        uint8[5] memory elements = [0, 1, 2, 3, 4];
        uint8 numberOfElements = 5;

        if (level >= FOUR_POWERS_MIN_LEVEL && level < FIVE_POWERS_MIN_LEVEL) {
            numberOfElements = 4;
            elements[_random % 5] = elements[4];
            _random /= 10;
        } else if (
            level >= THREE_POWERS_MIN_LEVEL && level < FOUR_POWERS_MIN_LEVEL
        ) {
            numberOfElements = 3;
            elements[_random % 5] = elements[4];
            _random /= 10;
            elements[_random % 4] = elements[3];
            _random /= 10;
        } else if (level < THREE_POWERS_MIN_LEVEL) {
            numberOfElements = 2;
            elements[_random % 5] = elements[4];
            _random /= 10;
            elements[_random % 4] = elements[3];
            _random /= 10;
            elements[_random % 3] = elements[2];
            _random /= 10;
        }
        ZaiStruct.Powers memory p;

        while (_points != 0) {
            _random /= 10;

            if (elements[_random % numberOfElements] == 0) {
                ++p.water;
            } else if (elements[_random % numberOfElements] == 1) {
                ++p.fire;
            } else if (elements[_random % numberOfElements] == 2) {
                ++p.metal;
            } else if (elements[_random % numberOfElements] == 3) {
                ++p.air;
            } else if (elements[_random % numberOfElements] == 4) {
                ++p.stone;
            }
            --_points;
            if (_random == 0) {
                _random = random;
            }
        }
        return p;
    }

    function _getGodsPowers(uint256 _ipfsId)
        internal
        pure
        returns (ZaiStruct.Powers memory powers)
    {
        if (_ipfsId == 1 || _ipfsId == 2) {
            powers.water = 3;
            powers.fire = 3;
            powers.metal = 3;
            powers.air = 3;
            powers.stone = 3;
        }
        if (_ipfsId == 3) {
            powers.water = 10;
        }
        if (_ipfsId == 4) {
            powers.fire = 10;
        }
        if (_ipfsId == 5) {
            powers.metal = 10;
        }
        if (_ipfsId == 6) {
            powers.air = 10;
        }
        if (_ipfsId == 7) {
            powers.stone = 10;
        }
    }

    function _updatePowers(
        uint256 level,
        ZaiStruct.Powers memory powers,
        ZaiStruct.Powers memory toAdd,
        bool isGod
    ) internal pure returns (ZaiStruct.Powers memory) {
        powers.water += toAdd.water;
        powers.fire += toAdd.fire;
        powers.metal += toAdd.metal;
        powers.air += toAdd.air;
        powers.stone += toAdd.stone;

        uint256 nbOfElements;
        if (powers.water != 0) {
            ++nbOfElements;
        }
        if (powers.fire != 0) {
            ++nbOfElements;
        }
        if (powers.metal != 0) {
            ++nbOfElements;
        }
        if (powers.air != 0) {
            ++nbOfElements;
        }
        if (powers.stone != 0) {
            ++nbOfElements;
        }
        bool result;
        if (level >= FIVE_POWERS_MIN_LEVEL) {
            result = true;
        } else if (level >= FOUR_POWERS_MIN_LEVEL && nbOfElements <= 4) {
            result = true;
        } else if (level >= THREE_POWERS_MIN_LEVEL && nbOfElements <= 3) {
            result = true;
        } else if (level < THREE_POWERS_MIN_LEVEL && nbOfElements <= 2) {
            result = true;
        }
        if (!isGod) {
            require(result, "level not compatible with this upgrade");
        }
        return powers;
    }

    function getToAdd(uint256 _toAdd) internal pure returns (uint256) {
        return ((_toAdd * 105) / 100); // UPDATE AUDIT: game XP balance update mult 110 => 105
    }

    function getLevel(uint256 _xp) external pure returns (uint256) {
        return _getLevel(_xp);
    }

    function _getLevel(uint256 _xp) internal pure returns (uint256) {
        uint256 _xpNeededToGoUp = 10000;
        uint256 _level = 0;
        uint256 _toAdd = 10000;
        while (_xp >= _xpNeededToGoUp) {
            _level = _level + 1;
            _toAdd = getToAdd(_toAdd);
            _xpNeededToGoUp = _xpNeededToGoUp + _toAdd;
        }
        return _level;
    }

    function getNextLevelUpPoints(uint256 _level)
        external
        pure
        returns (uint256)
    {
        return _getNextLevelUpPoints(_level);
    }

    function _getNextLevelUpPoints(uint256 _level)
        internal
        pure
        returns (uint256)
    {
        if (_level == 0) {
            return 0;
        } else if (_level == 1) {
            return 10000;
        } else {
            uint256 _xpNeededToGoUp = 10000;
            uint256 _toAdd = 10000;
            for (uint256 i = 1; i < _level; ) {
                _toAdd = getToAdd(_toAdd);
                _xpNeededToGoUp = _xpNeededToGoUp + _toAdd;
                unchecked {
                    ++i;
                }
            }
            return _xpNeededToGoUp;
        }
    }
}
