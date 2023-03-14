// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Interfaces.sol";

// contract StakingReturnsFees is Ownable, ReentrancyGuard {
//     using SafeERC20 for IERC20;

//     struct UserInfo {
//         uint256 amount;
//         uint256 rewardDebt;
//         uint256 pendingRewards;
//     }

//     struct PoolInfo {
//         IERC20 lpToken;
//         uint256 lastRewardBlock;
//         uint256 accBZAIPerShare;
//     }

//     IAddresses public gameAddresses;
//     IERC20 public BZAI;

//     mapping(address => uint256) _lastIndexUserReceivedFees;
//     mapping(uint256 => uint256) _feesReceivedAtBlock;
//     mapping(uint256 => uint256) _totalLpsAtBlock;
//     uint256 public totalHistoryFees;
//     uint256[] _blockReceivedFees;

//     uint256 public BZAIPerBlock = 317 * 1E16; // 3,17 BZAI per block => 50M initial reward / 365 / 43200(block per day in polygon mainnet); 
//     uint256 public remainingBZAIReward = 50000000 * 1E18;

//     uint256 public minGasNeeded = 12000;

//     PoolInfo public liquidityMining;
//     mapping(address => UserInfo) public userInfo;

//     event Deposit(address indexed user, uint256 amount);
//     event Withdraw(address indexed user, uint256 amount);
//     event Claim(address indexed user, uint256 amount);

//     modifier onlyGame() {
//         require(msg.sender == IAddresses(gameAddresses).getPaymentsAddress(), "Only game allowed");
//         _;
//     }

//     //set Platform
//     function setGameAddresses(address _gameAddress) public onlyOwner {
//         gameAddresses = IAddresses(_gameAddress);
//     }

//     function setMinGasNeeded(uint256 _minGasNeeded) public onlyOwner {
//         minGasNeeded = _minGasNeeded;
//     }

//     function setTokensAddress(IERC20 _bzai, IERC20 _lpToken) external onlyOwner {
//         require(address(BZAI) == address(0) && address(liquidityMining.lpToken) == address(0), 'Tokens already set!');
//         BZAI = _bzai;
//         liquidityMining =
//             PoolInfo({
//                 lpToken: _lpToken,
//                 lastRewardBlock: 0,
//                 accBZAIPerShare: 0
//         });
//     }
    
//     function startMining(uint256 startBlock) external onlyOwner {
//         require(liquidityMining.lastRewardBlock == 0, 'Mining already started');
//         liquidityMining.lastRewardBlock = startBlock;
//         _blockReceivedFees.push(startBlock);
//     }

//     function getMiningStarted() external view returns(bool){
//         return liquidityMining.lastRewardBlock == 0;
//     }

//     function pendingRewards(address _user) external view returns (uint256) {
//         require(liquidityMining.lastRewardBlock > 0 && block.number >= liquidityMining.lastRewardBlock, 'Mining not yet started');
//         UserInfo storage user = userInfo[_user];
//         uint256 accBZAIPerShare = liquidityMining.accBZAIPerShare;
//         uint256 lpSupply = liquidityMining.lpToken.balanceOf(address(this));

//         if (block.number > liquidityMining.lastRewardBlock && lpSupply != 0) {
//             uint256 multiplier = block.number - liquidityMining.lastRewardBlock;
//             uint256 bzaiReward = multiplier * BZAIPerBlock;
//             accBZAIPerShare = liquidityMining.accBZAIPerShare + (bzaiReward * 1e12 / lpSupply);
//         }
//         return user.amount * accBZAIPerShare / 1e12 - user.rewardDebt + user.pendingRewards;
//     }

//     function updatePool() internal {
//         require(liquidityMining.lastRewardBlock > 0 && block.number >= liquidityMining.lastRewardBlock, 'Mining not yet started');
//         if (block.number <= liquidityMining.lastRewardBlock) {
//             return;
//         }
//         uint256 lpSupply = liquidityMining.lpToken.balanceOf(address(this));
//         if (lpSupply == 0) {
//             liquidityMining.lastRewardBlock = block.number;
//             return;
//         }
//         uint256 multiplier = block.number - liquidityMining.lastRewardBlock;
//         uint256 bzaiReward = multiplier * BZAIPerBlock;
//         liquidityMining.accBZAIPerShare = liquidityMining.accBZAIPerShare + (bzaiReward * 1e12 / lpSupply);
//         liquidityMining.lastRewardBlock = block.number;
//     }

//     function deposit(uint256 amount) external {
//         UserInfo storage user = userInfo[msg.sender];
//         updatePool();
//         if (user.amount > 0) {
//             _harvestFees(msg.sender);
//             uint256 pending = user.amount * liquidityMining.accBZAIPerShare / 1e12 - user.rewardDebt;
//             if (pending > 0) {
//                 user.pendingRewards += pending;
//             }
//         }
//         if (amount > 0) {
//             liquidityMining.lpToken.safeTransferFrom(address(msg.sender), address(this), amount);
//             user.amount += amount;
//             remainingBZAIReward -= amount;
//             _lastIndexUserReceivedFees[msg.sender] = _blockReceivedFees.length - 1;
//         }
//         user.rewardDebt = user.amount * liquidityMining.accBZAIPerShare / 1e12;
//         emit Deposit(msg.sender, amount);
//     }

//     function withdraw(uint256 amount) external {
//         UserInfo storage user = userInfo[msg.sender];
//         require(user.amount >= amount, "Withdrawing more than you have!");
//         updatePool();
//         _harvestFees(msg.sender);
//         uint256 pending = user.amount * liquidityMining.accBZAIPerShare / 1e12 - user.rewardDebt;
//         if (pending > 0) {
//             user.pendingRewards += pending;
//         }
//         if (amount > 0) {
//             user.amount -= amount;
//             liquidityMining.lpToken.safeTransfer(address(msg.sender), amount);
//             remainingBZAIReward -= amount;
//         }
//         user.rewardDebt = user.amount * liquidityMining.accBZAIPerShare / 1e12;
//         emit Withdraw(msg.sender, amount);
//     }

//     function claim() external {
//         UserInfo storage user = userInfo[msg.sender];
//         updatePool();
//         _harvestFees(msg.sender);
//         uint256 pending = user.amount * liquidityMining.accBZAIPerShare / 1e12 - user.rewardDebt;
//         if (pending > 0 || user.pendingRewards > 0) {
//             user.pendingRewards += pending;
//             uint256 claimedAmount = _safeBzaiTransfer(msg.sender, user.pendingRewards);
//             remainingBZAIReward -= claimedAmount;

//             emit Claim(msg.sender, claimedAmount);
//             user.pendingRewards -= claimedAmount;
//         }
//         user.rewardDebt = user.amount * liquidityMining.accBZAIPerShare / 1e12;
//     }

//     function _safeBzaiTransfer(address to, uint256 amount) internal returns (uint256) {
//         if (amount > remainingBZAIReward) {
//             BZAI.safeTransfer(to, remainingBZAIReward);
//             return remainingBZAIReward;
//         } else {
//             BZAI.safeTransfer(to, amount);
//             return amount;
//         }
//     }

// // ========================================================
// //           BZAI fees for stakers               
// // ========================================================

//     function getBZAIRewardForUser(address _user) external view returns (uint256 amount){
//         (amount, ) = _getBZAIRewardForUser(_user);
//     }

//     function _harvestFees(address _user) internal nonReentrant{
//         (uint256 _toSend, uint256 _lastBlockReceivedFees) = _getBZAIRewardForUser(_user);
//         _lastIndexUserReceivedFees[_user] = _lastBlockReceivedFees;
//         if(_toSend > 0){
//            _safeBzaiTransfer(_user,_toSend);
//         }
//     }

//         // get the reward value user can claim
//     function _getBZAIRewardForUser(address _user) internal view returns (uint256 value, uint256 lastIndexReceivedFees) {
//         lastIndexReceivedFees = _blockReceivedFees.length - 1;
//         if(
//             userInfo[_user].amount > 0 && 
//             _lastIndexUserReceivedFees[_user] < _blockReceivedFees.length - 1
//           ) {
//             uint256 length = _blockReceivedFees.length;

//             for (uint256 i = _lastIndexUserReceivedFees[_user] + 1; i < length; ) {
//                 value += 
//                     _feesReceivedAtBlock[_blockReceivedFees[i]] 
//                     * userInfo[_user].amount 
//                     / _totalLpsAtBlock[_blockReceivedFees[i]];

//                 if(gasleft() <= minGasNeeded){
//                     lastIndexReceivedFees = i;
//                     break;
//                 }

//                 unchecked{ ++i; }
//             }
//         }
//     }

//     // =========================================================================================
//     // Where contract received fees from platform
//     // =========================================================================================

//     function receiveFees(uint256 _amount) external onlyGame{
//         totalHistoryFees += _amount;
//         _feesReceivedAtBlock[block.number] = _amount;
//         _totalLpsAtBlock[block.number] = liquidityMining.lpToken.balanceOf(address(this));
//         _blockReceivedFees.push(block.number);
//     }
    
// }