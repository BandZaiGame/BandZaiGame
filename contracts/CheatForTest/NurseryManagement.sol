// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// import "../Nursery.sol";
// import "../NurseryManagement.sol";

// // Nursery is where eggs are created.
// // Each Nurseries can create 5 bronze eggs by day.
// // after 5th bronze is sold, silver egg can be sold with a delay of 24h
// // during this delay , owner of nursery can "reserve" this egg for himself , 
// // but he have to burn average price of all nurseries egg state price.
// // when an egg is sold it is transfered to buyer wallet, and it can be scratched(and a zai born) after the maturity duration
// abstract contract CheatNurseryManagement is NurseryManagement {

//     // ------------------------------------------- //
//     // TESTING FN TO DELETE !!!!!!!!!!!!!!
//     function cheatNurseryForTest(
//         uint256 _nurseryId
//     ) external {
//         _updateNextMint(_nurseryId, _nextStateToMint[_nurseryId]);
//     }

//     // ------------------------------------------- //

//     function tokenURI(uint256 tokenId)
//         public
//         view
//         virtual
//         override
//         returns (string memory)
//     {
//         return
//             string(
//                 abi.encodePacked(
//                     "https://ipfs.io/ipfs/",
//                     _CID,
//                     "/",
//                     nurseryMintedDatas[tokenId].platinumMinted >= 5 ? 5 : nurseryMintedDatas[tokenId].platinumMinted, 
//                     ".json"
//                 )
//             );
//     }

// }
