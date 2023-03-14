// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Interfaces.sol";

// Main NFT zai/card contract
// UPDATE AUDIT : add totalSupply() method

contract ZaiNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 _totalSupply;

    IAddresses public gameAddresses;
    IZaiMeta public zaiMeta;
    address public levelStorage;

    event GameAddressesSetted(address gameAddresses);

    constructor(address _zaiMeta, address _levelStorage)
        ERC721("BandZai_NFT_ZAI", "ZAI")
    {
        require(_zaiMeta != address(0), "ZaiMeta can't be address(0)");
        require(
            _levelStorage != address(0),
            "LevelStorage can't be address(0)"
        );
        zaiMeta = IZaiMeta(_zaiMeta);
        levelStorage = _levelStorage;
    }

    modifier onlyAuth() {
        require(
            gameAddresses.isAuthToManagedNFTs(msg.sender),
            "Not Authorized to manage Zai NFT"
        );
        _;
    }

    // UPDATE AUDIT : We now have 2 URI:
    //  - One with IPFS datas only : tokenURIipfs(uint256 tokenId)
    //  - One with dynamic Zai metadata (ex powers) tokenURI(uint256 tokenId)
    function tokenURIipfs(uint256 tokenId) public view returns (string memory) {
        return zaiMeta.getZaiURI(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "https://data.bandzai.games/zai/",
                    Strings.toString(tokenId)
                )
            );
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function setGameAddresses(address _address) external onlyOwner {
        require(gameAddresses == IAddresses(address(0x0)), "Already setted");
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function createNewChallenger() external returns (uint256) {
        require(msg.sender == address(zaiMeta), "Only ZaiMeta authorized");
        return _safeMintZai(levelStorage);
    }

    function _safeMintZai(address _to) internal returns (uint256) {
        _tokenIds.increment();
        uint256 _tokenId = _tokenIds.current();
        _totalSupply++;
        _safeMint(_to, _tokenId);
        return _tokenId;
    }

    function mintZai(
        address _to,
        string memory _zaiName,
        uint256 _state
    ) external onlyAuth returns (uint256) {
        uint256 _newItemId = _safeMintZai(_to);
        zaiMeta.createZaiDatas(_newItemId, _zaiName, _state, 0);

        return (_newItemId);
    }

    function isFree(uint256 _tokenId) external view returns (bool) {
        return (zaiMeta.isFree(_tokenId));
    }

    function getNextLevelUpPoints(uint256 _level)
        external
        view
        returns (uint256)
    {
        return zaiMeta.getNextLevelUpPoints(_level);
    }

    function getZai(uint256 _tokenId)
        external
        view
        returns (ZaiStruct.Zai memory)
    {
        return zaiMeta.getZai(_tokenId);
    }

    function burnZai(uint256 _tokenId) external returns (bool) {
        require(
            msg.sender ==
                gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS),
            "only Payment can burn Zai for getting piggyBank"
        );
        _totalSupply--;
        _burn(_tokenId);
        return true;
    }
}
