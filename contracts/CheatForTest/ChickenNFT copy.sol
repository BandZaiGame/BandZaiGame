// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "../Interfaces.sol";

// // chicken can cover ZaiEggs to accelerate its maturity

// contract CheatChickenNFT is ERC721Enumerable, Ownable {
//     using Counters for Counters.Counter;
//     Counters.Counter private _tokenIds;

//     mapping(uint256 => uint256) public seasonOfChicken;
//     mapping(uint256 => string) public seasonURI;

//     constructor() ERC721("Chicken_BandZai_NFT", "CHICKEN") {}

//     IAddresses public gameAddresses;

//     modifier onlyAuth() {
//         require(gameAddresses.isAuthToManagedNFTs(msg.sender), "Not allowed");
//         _;
//     }

//     function setGameAddresses(address _address) external onlyOwner {
//         require(gameAddresses == IAddresses(address(0x0)));
//         gameAddresses = IAddresses(_address);
//     }

//     // ==============================
//     // Cheat function for test => must be delete before deployment
//     function getChicken() external returns (uint256) {
//         _tokenIds.increment();
//         uint256 _newTokenId = _tokenIds.current();
//         _safeMint(msg.sender, _newTokenId);

//         return (_newTokenId);
//     }

//     // ==============================

//     function setSeasonURI(uint256 _season, string memory _URI)
//         external
//         onlyOwner
//     {
//         seasonURI[_season] = _URI;
//     }

//     function tokenURI(uint256 tokenId)
//         public
//         view
//         virtual
//         override
//         returns (string memory)
//     {
//         return seasonURI[seasonOfChicken[tokenId]];
//     }

//     function mintChicken(address _to) external onlyAuth returns (uint256) {
//         _tokenIds.increment();
//         uint256 _newTokenId = _tokenIds.current();
//         _safeMint(_to, _newTokenId);

//         uint256 _currentSeason = IipfsIdStorage(
//             gameAddresses.getIpfsStorageAddress()
//         ).getCurrentSeason();

//         seasonOfChicken[_newTokenId] = _currentSeason;

//         return (_newTokenId);
//     }
// }
