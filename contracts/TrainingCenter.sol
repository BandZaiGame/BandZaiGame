// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Interfaces.sol";

// NFT training center
// at creation training center got 3 slots of training , and can be upgrade to 10 slots
// UPDATE AUDIT : add totalSupply() method
contract TrainingCenter is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 _totalSupply;

    IAddresses public gameAddresses;

    address public openAndCloseAddress;
    address public trainingManagementAddress;

    string _CID;

    uint256 _preMintNumber;

    mapping(uint256 => uint256) _numberOfTrainingSpots;

    event GameAddressesSetted(address gameAddresses);
    event AddressesUpdated(address openAndClose, address trainingManagement);
    event CIDSetted(string CID);

    constructor(
        uint256 _preMint,
        address _NFTreserve,
        string memory _cid
    ) ERC721("Training_Center_NFT", "TNFT") {
        _preMintNumber = _preMint;
        _CID = _cid;
        for (uint256 i; i < _preMint; ) {
            _numberOfTrainingSpots[_mintTrainingCenter(_NFTreserve)] = 3;
            unchecked {
                ++i;
            }
        }
    }

    modifier onlyAuth() {
        require(
            trainingManagementAddress == msg.sender ||
                openAndCloseAddress == msg.sender,
            "Not authorized to managed Training center"
        );
        _;
    }

    function setCID(string memory _Cid) external onlyOwner {
        _CID = _Cid;
        emit CIDSetted(_Cid);
    }

    function getPreMintNumber() external view returns (uint256) {
        return _preMintNumber;
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
                    _numberOfTrainingSpots[tokenId],
                    ".json"
                )
            );
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
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
        trainingManagementAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.TRAINING_MANAGEMENT
        );
        openAndCloseAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.OPEN_AND_CLOSE
        );
        emit AddressesUpdated(openAndCloseAddress, trainingManagementAddress);
    }

    // UPDATE AUDIT : call trainingManagement to init spot number of new center
    function mintTrainingCenter(address _to)
        external
        onlyAuth
        returns (uint256)
    {
        _totalSupply++;
        uint256 _tokenId = _mintTrainingCenter(_to);
        ITrainingManagement(trainingManagementAddress).initSpotsNumber(
            _tokenId
        );

        return _tokenId;
    }

    function _mintTrainingCenter(address _to) internal returns (uint256) {
        _tokenIds.increment();
        uint256 _newItemId = _tokenIds.current();
        _numberOfTrainingSpots[_newItemId] = 3;

        _safeMint(_to, _newItemId);
        return (_newItemId);
    }

    function numberOfTrainingSpots(uint256 _tokenId)
        external
        view
        returns (uint256)
    {
        return _numberOfTrainingSpots[_tokenId];
    }

    function addTrainingSpots(uint256 _tokenId, uint256 _quantity)
        external
        onlyAuth
        returns (bool)
    {
        require(_quantity != 0, "0 not accepted");
        require(
            _numberOfTrainingSpots[_tokenId] + _quantity <= 10,
            "Max spots already hit"
        );
        _numberOfTrainingSpots[_tokenId] += _quantity;
        return true;
    }

    function burn(uint256 _tokenId) external onlyAuth {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        _totalSupply--;
        _burn(_tokenId);
    }
}
