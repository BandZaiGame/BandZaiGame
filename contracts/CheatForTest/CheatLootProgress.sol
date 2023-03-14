// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "../Interfaces.sol";

// // if a player make a fight each day, he will won loot box on 7th day of each week
// // loot are composed of potion, and each 5 weeks, player can get an Egg
// contract CheatLootProgress is Ownable{

//     IAddresses public gameAddresses;

//     uint256 _nonce;

//     struct WeeklyLoot{
//         bool claimable;
//         bool claimed;
//     }

//     struct Progress {
//         uint256 lastActionTimestamp;
//         uint256 dayOfWeek;
//         uint256 weekNumber;
//         uint256 lastLootClaimable;
//         mapping(uint256 => WeeklyLoot) weeklyLootClaimed;
//     }

//     mapping(address => Progress) _progress;

//     event NewLootResult(address indexed user,string lootType, uint256[4] loots);


//     modifier onlyGame{
//         require(msg.sender == gameAddresses.getFightAddress(), "Only game authorized");
//         _;
//     }

//     function setGameAddresses(address _address) external onlyOwner {
//         require(gameAddresses == IAddresses(address(0x0)));
//         gameAddresses = IAddresses(_address);
//     }

// // TESTING Functions => to delete
// //===============================


//     function createFakeForTest(uint256 _weekNb, uint256 _dayNb) external {
//         require(_dayNb >= 1 && _dayNb <= 7, "Not good day value");
//         Progress storage p = _progress[msg.sender];
//         p.lastActionTimestamp = block.timestamp;
//         p.dayOfWeek = _dayNb;
//         p.weekNumber = _weekNb;
//     }

//     function unlockWeeklyLootForTest(uint256 _weekNb)external {
//         Progress storage p = _progress[msg.sender];
//         p.weekNumber = _weekNb;
//         for(uint256 i =_weekNb ; i > 0 ; ){
//             p.weeklyLootClaimed[i].claimable = true;
//             p.weeklyLootClaimed[i].claimed = false;
//             unchecked{ --i; }
//         }
//     }

// //===============================
// // TESTING Functions => to delete


//     function getUserProgress(address _user) external view returns(uint256 lastActionTimestamp,uint256 dayOfWeek,uint256 weekNumber, uint256 lastLootClaimable){
//         return _getUserProgress(_user);
//     }

//     function _getUserProgress(address _user) internal view returns(uint256 lastActionTimestamp,uint256 dayOfWeek,uint256 weekNumber, uint256 lastLootClaimable){
//         Progress storage p = _progress[_user];
//         uint256 _beginningDay = _getDayBegining();

//         if(p.lastActionTimestamp == 0){
//             return(0,0,1,0);
//         }
//         else if(
//             p.lastActionTimestamp >= _beginningDay || 
//             _beginningDay - p.lastActionTimestamp <= 1 days
//             ){
//             return(p.lastActionTimestamp,p.dayOfWeek,p.weekNumber,p.lastLootClaimable);
//         }
//         else if(_beginningDay - p.lastActionTimestamp <= 7 days ){
//             return(p.lastActionTimestamp,0,p.weekNumber,p.lastLootClaimable);
//         }
//         else if(
//                 _beginningDay - p.lastActionTimestamp > 7 days &&
//                 _beginningDay - p.lastActionTimestamp < 14 days
//                 ){
//             return(p.lastActionTimestamp,0,p.weekNumber > 1 ? p.weekNumber - 1 : 1,p.lastLootClaimable);
//         }
//         else if(_beginningDay - p.lastActionTimestamp >= 14 days){
//             return(p.lastActionTimestamp,0,1,p.lastLootClaimable);
//         }
//     }

//     function getWeekLootClaimedDatas(address _user, uint256 _weekNumber) external view returns(bool claimable, bool claimed){
//         return _getWeekLootClaimedDatas(_user, _weekNumber);
//     }

//     function _getWeekLootClaimedDatas(address _user, uint256 _weekNumber) internal view returns(bool claimable, bool claimed){
//         Progress storage p = _progress[_user];
//         return (p.weeklyLootClaimed[_weekNumber].claimable, p.weeklyLootClaimed[_weekNumber].claimed);
//     }

//     function _getDayBegining() internal view returns(uint256){
//         return IRanking(gameAddresses.getRankingContract()).getDayBegining();
//     }

//     function updateUserProgress(address _user) external onlyGame{
//         Progress storage p = _progress[_user];
//         uint256 _beginningDay = _getDayBegining();
//         if(p.lastActionTimestamp == 0){
//             p.lastActionTimestamp = block.timestamp;
//             p.dayOfWeek = 1;
//             p.weekNumber = 1;
//         }else{
//             if(_beginningDay >= p.lastActionTimestamp){
//                 if(_beginningDay - p.lastActionTimestamp <= 1 days){
//                     p.lastActionTimestamp = block.timestamp;
//                     p.dayOfWeek += 1;
//                     if(p.dayOfWeek == 8){
//                         if(p.lastLootClaimable < p.weekNumber){
//                             p.weeklyLootClaimed[p.weekNumber].claimable = true;
//                             p.lastLootClaimable = p.weekNumber;
//                         }
//                         p.weekNumber += 1;
//                         p.dayOfWeek = 1;
//                     }
//                 }else {
//                     p.dayOfWeek = 1;
//                     if(
//                         _beginningDay - p.lastActionTimestamp > 7 days &&
//                         _beginningDay - p.lastActionTimestamp < 14 days
//                         ){
//                         if(p.weekNumber > 1){
//                             p.weekNumber -= 1;
//                         }
//                     } else if(_beginningDay - p.lastActionTimestamp >= 14 days){
//                         p.weekNumber = 1;
//                     }
//                     p.lastActionTimestamp = block.timestamp;
//                 } 
//             }
//         }
//     }    

//     function claimLoot(uint256 _weekNumber) external {
//         Progress storage p = _progress[msg.sender];

//         require(p.weeklyLootClaimed[_weekNumber].claimable && !p.weeklyLootClaimed[_weekNumber].claimed, "Reward not available");
//         if(_weekNumber > 1){
//             require(p.weeklyLootClaimed[_weekNumber - 1].claimed, "Previous week loot hasn't been claimed");
//         }
//         p.weeklyLootClaimed[_weekNumber].claimable = false;
//         p.weeklyLootClaimed[_weekNumber].claimed = true;

//         uint256[4] memory _loot;

//         if(_weekNumber % 10 == 0){
//             uint256 _eggLoot = _getEggsLoot(msg.sender, true);
//             _loot[0] = (_eggLoot);
//             emit NewLootResult(msg.sender, "eggLoot", _loot);
//         } else if(_weekNumber % 5 == 0){
//             uint256 _eggLoot = _getEggsLoot(msg.sender, false);
//             _loot[0] = (_eggLoot);
//             emit NewLootResult(msg.sender, "eggLoot", _loot);
//         }else{
//             uint256 _tens = 0;
//             while(_weekNumber > 10){
//                 _weekNumber -= 10;
//                 _tens += 1;
//             } 
//             uint256 _nbOfPotions = _tens + (_weekNumber < 5 ? 1 : 2);
//             uint256 _minLevel = _weekNumber + (_tens == 0 ? 5 : _tens * 15);
//             _loot = _getPotionLoot(
//                 msg.sender, 
//                 // limit to 4 potions
//                 _nbOfPotions > 4 ? 4:_nbOfPotions, 
//                 _minLevel, 
//                 _minLevel * 2);
//             emit NewLootResult(msg.sender, "potionsLoot", _loot);
//         }
//     }

//     function _getPotionLoot(address _user, uint256 _numberOfPotions, uint256 _minLevel, uint256 _maxLevel) internal returns(uint256[4] memory potions){
//         IPotions I = IPotions(gameAddresses.getPotionAddress());

//         uint256[8] memory r = _generateRandomDatas();
//         uint256[4] memory _potions;

//         for(uint256 i = 0 ; i < _numberOfPotions ; ){
//             uint256 _power = _minLevel + (r[i] % (_maxLevel - _minLevel)); 
//             uint256 _potionType = r[i] % 5;

//             _potions[i] = I.offerPotion(_potionType,_power, _user);
//             unchecked{ ++i; }
//         }
//         return _potions;
//     }

//     // _tensRandom true allows to random a gold or a platinum
//     function _getEggsLoot(address _user, bool _tensRandom) internal returns(uint256 egg){
//         IEggs eggs = IEggs(gameAddresses.getEggsAddress());

//         uint256[8] memory r = _generateRandomDatas();
//         uint256 _state = r[0] % 3;
//         if(_tensRandom){
//             _state += 1;
//         }        
        
//         return eggs.mintEgg(_user, _state, 0);
//     }

//     // utils

//     function _generateRandomDatas() private returns (uint256[8] memory) {
//         uint256 r = IOracle(gameAddresses.getOracleAddress()).getRandom();
//         _nonce += 1;
//         uint256 [8] memory randoms;
//         uint256 _mult = 1000;
//         for (uint256 i = 0; i < 7; ){
//             randoms[i] = uint256(r / _mult); 
//             _mult = _mult * 100;
//             unchecked{ ++i; }
//         }
//         return(randoms);
//     }


// }