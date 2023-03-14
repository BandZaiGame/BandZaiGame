// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// chicken can cover ZaiEggs to accelerate its maturity
// UPDATE AUDIT : add totalSupply() method

contract ChickenNFT is ERC721, Ownable, IChicken {
    uint256 private _totalSupply;

    IAddresses public gameAddresses;

    mapping(uint256 => uint256) public seasonOfChicken;
    mapping(uint256 => string) public seasonURI;

    event GameAddressesSetted(address gameAddresses);

    constructor() ERC721("Chicken_BandZai_NFT", "CHICKEN") {}

    modifier onlyAuth() {
        require(gameAddresses.isAuthToManagedNFTs(msg.sender), "Not allowed");
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

    function setSeasonURI(uint256 _season, string memory _URI)
        external
        onlyOwner
    {
        seasonURI[_season] = _URI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return seasonURI[seasonOfChicken[tokenId]];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function mintChicken(address _to) external onlyAuth returns (uint256) {
        _totalSupply++;
        uint256 _newTokenId = _totalSupply;

        uint256 _currentSeason = IipfsIdStorage(
            gameAddresses.getAddressOf(AddressesInit.Addresses.IPFS_STORAGE)
        ).getCurrentSeason();

        seasonOfChicken[_newTokenId] = _currentSeason;
        _safeMint(_to, _newTokenId);

        return (_newTokenId);
    }
}
