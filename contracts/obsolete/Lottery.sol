// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "../Interfaces.sol";

// contract Lottery is ERC721Enumerable, Ownable {

//     using Counters for Counters.Counter;
//     Counters.Counter private _tokenIds;

//     IERC20 public BZAI;

//     constructor(address _BZAI) ERC721("Lottery_NFT", "TICKET") {
//         BZAI = IERC20(_BZAI);
//     }

//     IAddresses public gameAddresses;

//     uint256 private nonce;

//     uint256 private ticketPrice = 1000 * 1E18;

//     uint256 private bronzeBoxPrice = 400 * 1E18;
//     uint256 private silverBoxPrice = 600 * 1E18;
//     uint256 private goldBoxPrice = 1200 * 1E18;

//     event NewBox (address indexed _user, uint256 _type, uint256[4] _potions, uint256 _ticket);

//     function setLotteryPrice(uint256 _ticket, uint256 _bronze, uint256 _silver, uint256 _gold) external onlyOwner {
//         ticketPrice = _ticket;
//         bronzeBoxPrice = _bronze;
//         silverBoxPrice = _silver;
//         goldBoxPrice = _gold;
//     }

//     function getLotteryPrices() external view returns(uint256 _ticket, uint256 _bronze, uint256 _silver, uint256 _gold){
//         return(
//             ticketPrice,
//             bronzeBoxPrice,
//             silverBoxPrice,
//             goldBoxPrice
//         );
//     }

//     function setGameAddresses(address _address) external onlyOwner{
//         gameAddresses = IAddresses(_address);
//     }

//     function offerTicket(address _address) external returns(uint256){
//         require(msg.sender == gameAddresses.getGameAddress(), "Only game can mint free ticket");
//         return(_mintTicket(_address));
//     }

//     function buyTicket() external returns(uint256){
//         address paymentAddress = gameAddresses.getPaymentsAddress();
//         require(payWithRewardOrWallet(msg.sender, paymentAddress, ticketPrice));

//         IPayments(paymentAddress).distributeFees(ticketPrice);
//         return(_mintTicket(msg.sender));
//     }

//     function buyBronzeBox() external {
//         _buyBox(0,msg.sender);
//     }  

//     function buySilverBox() external {
//         _buyBox(1,msg.sender);
//     }

//     function buyGoldBox() external {
//         _buyBox(2,msg.sender);
//     }

//     function _buyBox(uint256 _type, address _user) internal {
        
//         uint256 _price = _type == 0 ? bronzeBoxPrice : _type == 1 ? silverBoxPrice :goldBoxPrice;

//         address paymentAddress = gameAddresses.getPaymentsAddress();

//         require(payWithRewardOrWallet(msg.sender, paymentAddress, _price));
//         require(IPayments(paymentAddress).distributeFees(_price));

//         nonce += 1;
//         uint256 _random = _getRandom(keccak256(abi.encodePacked(_user, block.timestamp, nonce + _type)));
//         uint256 _numberOfMint = 3 + (_random % 2);

//         uint256 [4] memory potions;
//         uint256 ticket;

//         IPotions I = IPotions(gameAddresses.getPotionAddress());
//         uint256 _power = _type == 0 ? 5 : _type == 1 ? 10 :25;

//         for(uint256 i = 0 ; i < _numberOfMint ; ){
//             _random = _random / 10;
//             uint256 _potionType = _random % 5;

//             uint256 _newPotion = I.offerPotion(_potionType,_power,_user);
//             potions[i] = _newPotion;
//             unchecked{ ++i; }
//         }
//         if(_random % 10000 <= 200 + _type * 400){
//             ticket = _mintTicket(_user);
//         }

//         emit NewBox(_user, _type, potions, ticket);
//     }

//     function _mintTicket(address _address) internal returns(uint256){
//         _tokenIds.increment();
//         uint256 _newItemId = _tokenIds.current();
//         _safeMint(_address, _newItemId);

//         return (_newItemId);
//     }

//     function useTicket(uint256 _ticketID,string memory _name) external returns(uint256) {
//         require(ownerOf(_ticketID) == msg.sender,"Not your ticket");
//         _burn(_ticketID);
//         return(_lotteryMint(_name));
//     }

//     function buyRandomZai(string memory _name) external returns(uint256){
//         address paymentAddress = gameAddresses.getPaymentsAddress();
        
//         require(payWithRewardOrWallet(msg.sender, paymentAddress, ticketPrice));
//         require(IPayments(paymentAddress).distributeFees(ticketPrice));

//         return(_lotteryMint(_name));
//     }

//     function _lotteryMint (string memory _name)
//         internal
//         returns (uint256)
//     {
//         bytes32 _id = keccak256(abi.encodePacked(msg.sender, block.timestamp, nonce));
//         nonce ++;
//         uint256 _random = _getRandom(_id) % 10000;

//         uint256 _state;
//         if (_random <= 150) { //1,5%
//             _state = 3;
//         }
//         if (_random > 150 && _random <= 800) { // 800 - 150 = 650 => 6,5% 
//             _state = 2;
//         }
//         if (_random > 800 && _random <= 3000) { // 3000 - 800 = 2200 => 22%
//             _state = 1;
//         }
//         if (_random > 3000) { // 70%
//             _state = 0;
//         }

//         return _generateRandomZai( _name, msg.sender, _state);
//     }

//     function _generateRandomZai(
//         string memory _name,
//         address _user,
//         uint256 _state
//     ) internal returns (uint256) {
//         uint256 zaiId = IZaiNFT(gameAddresses.getZaiAddress()).mintZai(
//             _user,
//             _name,
//             _state
//         );
//         return zaiId;
//     }

//     function _getRandom(bytes32 _id) internal returns (uint256) {
//         return IOracle(gameAddresses.getOracleAddress()).getRandom(_id);
//     }

//     function payWithRewardOrWallet(address _user, address _recipient, uint256 _amount) internal returns(bool){
//         address _paymentAddress = gameAddresses.getPaymentsAddress();
//         uint256 _credit = IPayments(_paymentAddress).getMyReward(_user);
//         if(_credit == 0){
//             return(BZAI.transferFrom(_user, _recipient, _amount));
//         }else if(_credit > _amount){
//             return IPayments(_paymentAddress).useReward(_user,_amount);
//         }else {
//             IPayments(_paymentAddress).useReward(_user,_credit);
//             return(BZAI.transferFrom(_user, _recipient, _amount - _credit));
//         }
//     }
// }
