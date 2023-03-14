// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "../Interfaces.sol";

// contract ZaiStatsObs is Ownable {
//     IAddresses public gameAddresses;

//     //KINGS
//     struct King {
//         uint256 actualKing;
//         uint256 totalScore;
//         uint256 kingSince;
//     }

//     King public winKing;
//     King public drawKing;
//     King public lossKing;
//     King public totalFightKing;

//     event newWinKing(uint256 newKing, uint256 lastKing, uint256 during);
//     event newDrawKing(uint256 newKing, uint256 lastKing, uint256 during);
//     event newLossKing(uint256 newKing, uint256 lastKing, uint256 during);
//     event newTotalKing(uint256 newKing, uint256 lastKing, uint256 during);

//     mapping(uint256 => ZaiStruct.Stats) _zaiStats;

//     mapping(uint256 => uint256) _totalDayFight;
//     mapping(uint256 => uint256) _totalWeekFight;

//     // Use for front end stat about all powers in game
//     ZaiStruct.Powers public totalPowersInGame;

//     modifier onlyFight() {
//         require(
//             msg.sender == gameAddresses.getFightAddress(),
//             "Only game authorized"
//         );
//         _;
//     }

//     function setGameAddresses(address _address) external onlyOwner {
//         require(
//             gameAddresses == IAddresses(address(0x0)),
//             "game addresses already setted"
//         );
//         gameAddresses = IAddresses(_address);
//     }

//     function getZaiStats(uint256 _zaiId)
//         external
//         view
//         returns (
//             uint256 zaiTotalWins,
//             uint256 zaiTotalDraw,
//             uint256 zaiTotalLoss,
//             uint256 zaiTotalFights
//         )
//     {
//         ZaiStruct.Stats storage s = _zaiStats[_zaiId];
//         return (
//             s.zaiTotalWins,
//             s.zaiTotalDraw,
//             s.zaiTotalLoss,
//             s.zaiTotalFights
//         );
//     }

//     function getTotalDayFight(uint256 _day) external view returns (uint256) {
//         return _totalDayFight[_day];
//     }

//     function getTotalWeekFight(uint256 _week) external view returns (uint256) {
//         return _totalWeekFight[_week];
//     }

//     function updateCounterWinLoss(
//         uint256 _zaiId,
//         uint256 _challengerId,
//         uint256[30] memory _fightProgress,
//         IRanking IRank
//     ) external onlyFight returns (bool) {
//         require(_zaiId != 0 && _challengerId != 0, "Zai doesn't exist");
//         _updateTotalFights(IRank);
//         ZaiStruct.Stats storage p1 = _zaiStats[_zaiId];
//         ZaiStruct.Stats storage p2 = _zaiStats[_challengerId];
//         p1.zaiTotalFights += 1;

//         if (p1.zaiTotalFights > totalFightKing.totalScore) {
//             emit newTotalKing(
//                 _zaiId,
//                 totalFightKing.actualKing,
//                 block.timestamp - totalFightKing.kingSince
//             );
//             totalFightKing.totalScore = p1.zaiTotalFights;
//             totalFightKing.kingSince = block.timestamp;
//             totalFightKing.actualKing = _zaiId;
//         }

//         p2.zaiTotalFights += 1;

//         if (p2.zaiTotalFights > totalFightKing.totalScore) {
//             emit newTotalKing(
//                 _challengerId,
//                 totalFightKing.actualKing,
//                 block.timestamp - totalFightKing.kingSince
//             );
//             totalFightKing.totalScore = p2.zaiTotalFights;
//             totalFightKing.kingSince = block.timestamp;
//             totalFightKing.actualKing = _challengerId;
//         }

//         if (_fightProgress[1] > _fightProgress[2]) {
//             p1.zaiTotalWins += 1;

//             if (p1.zaiTotalWins > winKing.totalScore) {
//                 emit newWinKing(
//                     _zaiId,
//                     winKing.actualKing,
//                     block.timestamp - winKing.kingSince
//                 );
//                 winKing.totalScore = p1.zaiTotalWins;
//                 winKing.kingSince = block.timestamp;
//                 winKing.actualKing = _zaiId;
//             }
//         } else if (_fightProgress[1] == _fightProgress[2]) {
//             p1.zaiTotalDraw += 1;
//             if (p1.zaiTotalDraw > drawKing.totalScore) {
//                 emit newDrawKing(
//                     _zaiId,
//                     drawKing.actualKing,
//                     block.timestamp - drawKing.kingSince
//                 );
//                 drawKing.totalScore = p1.zaiTotalDraw;
//                 drawKing.kingSince = block.timestamp;
//                 drawKing.actualKing = _zaiId;
//             }
//         } else if (_fightProgress[2] > _fightProgress[1]) {
//             p1.zaiTotalLoss += 1;
//             if (p1.zaiTotalLoss > lossKing.totalScore) {
//                 emit newDrawKing(
//                     _zaiId,
//                     lossKing.actualKing,
//                     block.timestamp - lossKing.kingSince
//                 );
//                 lossKing.totalScore = p1.zaiTotalLoss;
//                 lossKing.kingSince = block.timestamp;
//                 lossKing.actualKing = _zaiId;
//             }
//         }
//         return true;
//     }

//     function _updateTotalFights(IRanking IRank) internal {
//         (uint256 dayNumber, uint256 weekNumber) = IRank
//             .getDayAndWeekRankingCounter();
//         _totalDayFight[dayNumber] += 1;
//         _totalWeekFight[weekNumber] += 1;
//     }

//     function updateAllPowersInGame(ZaiStruct.Powers memory toAdd)
//         external
//         returns (bool)
//     {
//         require(
//             msg.sender == gameAddresses.getZaiMetaAddress(),
//             "Not authorized3"
//         );
//         totalPowersInGame.water += toAdd.water;
//         totalPowersInGame.fire += toAdd.fire;
//         totalPowersInGame.metal += toAdd.metal;
//         totalPowersInGame.air += toAdd.air;
//         totalPowersInGame.stone += toAdd.stone;
//         return true;
//     }

//     function reduceAllPowersInGame(ZaiStruct.Powers memory toReduce)
//         external
//         returns (bool)
//     {
//         require(
//             msg.sender == gameAddresses.getZaiMetaAddress(),
//             "Not authorized3"
//         );
//         totalPowersInGame.water -= toReduce.water;
//         totalPowersInGame.fire -= toReduce.fire;
//         totalPowersInGame.metal -= toReduce.metal;
//         totalPowersInGame.air -= toReduce.air;
//         totalPowersInGame.stone -= toReduce.stone;
//         return true;
//     }
// }
