// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Interfaces.sol";

// UPDATE AUDIT : add totalSupply() method
contract Laboratory is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 _totalSupply;

    IAddresses public gameAddresses;
    address public openAndClose;
    address public laboManagement;

    uint256 _preMintNumber;

    string _CID;

    mapping(uint256 => uint256) private _numberOfWorkingSpots;
    mapping(uint256 => uint256) _creditsLastUpdate;

    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(address laboManagement, address openAndClose);

    constructor(
        uint256 _preMint,
        address _NFTreserve,
        string memory _cid
    ) ERC721("LABO_NFT", "LAB") {
        require(_preMint < 30, "Can't premint so much");
        _CID = _cid;
        _preMintNumber = _preMint;
        for (uint256 i; i < _preMint; ) {
            _numberOfWorkingSpots[_mintLaboratory(_NFTreserve)] = 3;
            unchecked {
                ++i;
            }
        }
    }

    modifier onlyAuth() {
        require(
            msg.sender == openAndClose || msg.sender == laboManagement,
            "Not authorized to managed Labo NFT"
        );
        _;
    }

    function setCID(string memory _Cid) external onlyOwner {
        _CID = _Cid;
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
                    "https://ipfs.io/ipfs/",
                    _CID,
                    "/",
                    _numberOfWorkingSpots[tokenId],
                    ".json"
                )
            );
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function setGameAddresses(address _address) public onlyOwner {
        require(gameAddresses == IAddresses(address(0x0)));
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function updateInterfaces() external {
        openAndClose = gameAddresses.getAddressOf(
            AddressesInit.Addresses.OPEN_AND_CLOSE
        );
        laboManagement = gameAddresses.getAddressOf(
            AddressesInit.Addresses.LABO_MANAGEMENT
        );
        emit InterfacesUpdated(laboManagement, openAndClose);
    }

    function getPreMintNumber() external view returns (uint256) {
        return _preMintNumber;
    }

    // UPDATE AUDIT : call laboManagement to init spot number of new center
    function mintLaboratory(address _to) external onlyAuth returns (uint256) {
        uint256 _tokenId = _mintLaboratory(_to);
        ILabManagement(laboManagement).initSpotsNumber(_tokenId);

        return _tokenId;
    }

    function _mintLaboratory(address _to) internal returns (uint256) {
        _tokenIds.increment();
        uint256 _newItemId = _tokenIds.current();
        _totalSupply++;
        _safeMint(_to, _newItemId);
        _numberOfWorkingSpots[_newItemId] = 3;
        _creditsLastUpdate[_newItemId] = block.timestamp;

        return (_newItemId);
    }

    function getCreditLastUpdate(uint256 _tokenId)
        external
        view
        returns (uint256)
    {
        return _creditsLastUpdate[_tokenId];
    }

    function updateCreditLastUpdate(uint256 _tokenId)
        external
        onlyAuth
        returns (bool)
    {
        _creditsLastUpdate[_tokenId] = block.timestamp;
        return true;
    }

    function numberOfWorkingSpots(uint256 _tokenId)
        external
        view
        returns (uint256)
    {
        return _numberOfWorkingSpots[_tokenId];
    }

    function updateNumberOfWorkingSpots(uint256 _tokenId, uint256 _quantity)
        external
        onlyAuth
        returns (bool)
    {
        require(_quantity != 0, "0 not accepted");
        require(
            _numberOfWorkingSpots[_tokenId] + _quantity <= 10,
            "Max spots already hit"
        );
        _numberOfWorkingSpots[_tokenId] += _quantity;
        return true;
    }

    function burn(uint256 _tokenId) external onlyAuth {
        _totalSupply--;
        _burn(_tokenId);
    }
}
