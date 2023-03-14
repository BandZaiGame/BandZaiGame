// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// contract used for store each Zai from a level
// fighting versus environment will give oponent from same level

contract LevelStorage is Ownable, ERC721Holder {
    using EnumerableSet for EnumerableSet.UintSet;

    IAddresses public gameAddresses;

    mapping(uint256 => EnumerableSet.UintSet) private levelFighters;
    address public zaiMeta;

    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(address zaiMeta);
    event AddZaiToLevel(
        uint256 indexed zaiId,
        uint256 level,
        uint256 numberOfZaiInLevel
    );
    event RemoveZaiFromLevel(
        uint256 indexed zaiId,
        uint256 level,
        uint256 numberOfZaiInLevel
    );

    modifier canRemoveOrAdd() {
        require(msg.sender == zaiMeta, "Not Authorized to remove or add");
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
        zaiMeta = gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_META);
        emit InterfacesUpdated(zaiMeta);
    }

    function addFighter(uint256 _level, uint256 _zaiId)
        external
        canRemoveOrAdd
        returns (bool)
    {
        levelFighters[_level].add(_zaiId);
        emit AddZaiToLevel(_zaiId, _level, levelFighters[_level].length());
        return true;
    }

    function removeFighter(uint256 _level, uint256 _zaiId)
        external
        canRemoveOrAdd
        returns (bool)
    {
        levelFighters[_level].remove(_zaiId);
        emit RemoveZaiFromLevel(_zaiId, _level, levelFighters[_level].length());
        return true;
    }

    function getLevelLength(uint256 _level) external view returns (uint256) {
        return levelFighters[_level].length();
    }

    function getRandomZaiFromLevel(
        uint256 _level,
        uint256 _idForbiden,
        uint256 _random
    ) external view returns (uint256) {
        if (_level > 50) {
            // all level 50 + got same elements points so they can fight together
            _level = 50;
        }
        uint256 index = _random % (levelFighters[_level].length());

        if (levelFighters[_level].at(index) == _idForbiden) {
            if (index == 0) {
                index = 1;
            } else {
                --index;
            }
        }

        return (levelFighters[_level].at(index));
    }
}
