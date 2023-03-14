// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// contract used to store IPFS Uri
// URI return multiple file ex:  /content/gold/1.json where 1.json is the NFT files
// NFTs got an IPFS id and a ERC721 id.
contract IpfsIdStorage is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    IAddresses public gameAddresses;
    IOracle public Oracle;
    address public zaiMeta;

    // UPDATE AUDIT : add events and delete storing of each Zai in state EnumerableSet
    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(address zaiMeta, address oracle);
    event GodMinted(uint256 nftId, uint256 ipfsId, uint256 season);
    event ZaiMinted(string indexed zaiType, uint256 nftId, uint256 season);
    event SeasonCIDUpdated(string indexed CID, uint256 season);

    uint256 private _currentSeason;
    mapping(uint256 => uint256) public seasonCreationTimestamp;

    // at deployment, _maxIds (for each state) is setted to 50.
    // this way, random will give an ipfsId between 1 to 50
    // IpfsId is delete from list (_freeIds[]) and assigned to NFT Id.  We add 51 for futur random
    mapping(uint256 => uint256[4]) private _maxIds;

    //_freeIds[season][state]
    mapping(uint256 => mapping(uint256 => EnumerableSet.UintSet))
        private _freeIds;
    mapping(uint256 => string) private _seasonCid;
    // each season will have 7 gods : 2 masters gods (mum and dad) and 1 god by elements(fire, water ...)
    mapping(uint256 => uint256[]) private _mintedGods;

    modifier onlyAuth() {
        require(
            msg.sender == zaiMeta,
            "Not Authorized to managed IPFS storage"
        );
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
        Oracle = IOracle(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ORACLE)
        );
        zaiMeta = gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_META);
        emit InterfacesUpdated(zaiMeta, address(Oracle));
    }

    function setSeasonCID(uint256 _season, string memory _cid)
        external
        onlyOwner
    {
        _seasonCid[_season] = _cid;
        emit SeasonCIDUpdated(_cid, _season);
    }

    function getSeasonCID(uint256 _season)
        external
        view
        returns (string memory)
    {
        return _seasonCid[_season];
    }

    function getMintedGods(uint256 _season)
        external
        view
        returns (uint256[] memory)
    {
        return _mintedGods[_season];
    }

    function getCurrentSeason() external view returns (uint256) {
        return _currentSeason;
    }

    function updateSeason() external onlyOwner {
        if (_currentSeason != 0) {
            require(
                _mintedGods[_currentSeason].length == 7,
                "New season need all gods minted"
            );
        }
        ++_currentSeason;
        seasonCreationTimestamp[_currentSeason] = block.timestamp;
    }

    function _getGodId() internal view returns (uint256) {
        uint256 _godId;
        for (uint256 i; i < _freeIds[_currentSeason][3].length(); ) {
            if (_freeIds[_currentSeason][3].at(i) <= 7) {
                _godId = _freeIds[_currentSeason][3].at(i);
                break;
            }
            unchecked {
                ++i;
            }
        }
        return _godId;
    }

    // used to create a list of IDs who can be minted
    function setMultiplesIds(
        uint256 _ids,
        uint256 _season,
        uint256 _state
    ) external onlyOwner {
        for (uint256 i = _maxIds[_season][_state] + 1; i < _ids; ) {
            require(_addID(_season, _state, i));
            unchecked {
                ++i;
            }
        }
        _maxIds[_season][_state] = _ids;
    }

    function _addID(
        uint256 _season,
        uint256 _state,
        uint256 _id
    ) internal returns (bool) {
        return _freeIds[_season][_state].add(_id);
    }

    function _removeID(
        uint256 _season,
        uint256 _state,
        uint256 _id
    ) internal returns (bool) {
        return _freeIds[_season][_state].remove(_id);
    }

    function getIdsLength(uint256 _season, uint256 _state)
        external
        view
        returns (uint256)
    {
        return _freeIds[_season][_state].length();
    }

    function getTokenURI(
        uint256 _season,
        uint256 _state,
        uint256 _id
    ) external view returns (string memory) {
        string memory _stateName;
        if (_state == 0) {
            _stateName = "bronze";
        } else if (_state == 1) {
            _stateName = "silver";
        } else if (_state == 2) {
            _stateName = "gold";
        } else if (_state == 3) {
            _stateName = "platinum";
        }
        return
            string(
                abi.encodePacked(
                    "https://ipfs.io/ipfs/",
                    _seasonCid[_season],
                    "/content/",
                    _stateName,
                    "/",
                    Strings.toString(_id),
                    ".json"
                )
            );
    }

    function getNextIpfsId(uint256 _state, uint256 _nftId)
        external
        onlyAuth
        returns (uint256 newIpfsId)
    {
        // 6 months after launch, if all gods hasn't been minted
        // we raise probability to mint remaining gods unminted each day
        if (
            _state == 3 &&
            block.timestamp >=
            seasonCreationTimestamp[_currentSeason] + 180 days &&
            _mintedGods[_currentSeason].length < 7
        ) {
            uint256 _rand = Oracle.getRandom();
            if (
                block.timestamp >=
                seasonCreationTimestamp[_currentSeason] +
                    180 days +
                    ((_rand % 30) * 1 days)
            ) {
                newIpfsId = _getGodId();
            }
        }
        if (newIpfsId == 0) {
            newIpfsId = _getRandomId(_state);
        }
        if (_state == 3 && newIpfsId <= 7) {
            _mintedGods[_currentSeason].push(newIpfsId);
            emit GodMinted(_nftId, newIpfsId, _currentSeason);
        }
        emit ZaiMinted(
            _state == 0 ? "bronze" : _state == 1 ? "silver" : _state == 2
                ? "gold"
                : "platinum",
            _nftId,
            _currentSeason
        );
        _removeID(_currentSeason, _state, newIpfsId);
        ++_maxIds[_currentSeason][_state];
        _addID(_currentSeason, _state, _maxIds[_currentSeason][_state]);
    }

    function _getRandomId(uint256 _state) internal returns (uint256) {
        uint256 _rand = Oracle.getRandom();

        uint256 index = _rand % (_freeIds[_currentSeason][_state].length());
        return _freeIds[_currentSeason][_state].at(index);
    }
}
