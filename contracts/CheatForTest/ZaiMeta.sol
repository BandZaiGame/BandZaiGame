// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// import "../Interfaces.sol";
// import "../ZaiMeta.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// // Zai meta data
// //
// abstract contract CheatZaiMeta is ZaiMeta {
    

//     // ---------------------------------
//     // cheat function TO DELETE BEFORE DEPLOYMENT
//     // ---------------------------------

//     function cheatZaiManaForTest(uint256 _zaiId) external {
//         ZaiStruct.Zai storage z = _zai[_zaiId];

//         z.manaMax = 10000;
//         z.mana = 10000;
//     }

//     function cheatZaiXpForTest(uint256 _id, uint256 _xp) external {
//         ZaiStruct.Zai storage z = _zai[_id];
//         z.xp += _xp;
//         // update level
//         uint256 level = _getLevel(z.xp);

//         if(z.level < 50){
//             if (ILevel.getLevelLength(level) < 10) {
//                 for (uint256 i = 0; i < 3; ) {
//                     uint256 _newItemId = IZai.createNewChallenger();
//                     _preMintZai(level, _newItemId);
//                     unchecked {
//                         ++i;
//                     }
//                 }
//             }
//         }

//         if (level > z.level) {
//             if (z.level < 50) {
//                 // update new level
//                 // max element points is on level 50 : 3 x 50 + 8pts = 158pts
//                 uint256 _numberOfLevelUp = (level > 50 ? 50 : level) - z.level;
//                 // zai win 3 points by level raised
//                 z.creditForUpgrade = z.creditForUpgrade + (_numberOfLevelUp * 3);
//                 // zai update from level storage
//                 require(ILevel.removeFighter(z.level, _id));
//                 require(ILevel.addFighter((level > 50 ? 50 : level), _id));
//             }
//             z.level = level;
//         }
//     }

//     // ---------------------------------
//     // ---------------------------------
//     // ---------------------------------

    
// }