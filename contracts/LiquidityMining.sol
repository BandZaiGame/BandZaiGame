// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// classic farming contract
contract LiquidityMining is Ownable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 lastRewardBlock;
        uint256 accBZAIPerShare;
    }

    IERC20 public BZAI;

    // UPDATE AUDIT : BandZai will have a fairlaunch and release of token in this contract change
    uint256 _halvingNb = 0;
    uint256[] BZAIPerBlockAtHalving = [
        3086 * 1E16, // Month 1 : 40 M / 30 / 43200 = 30.86 BZAI/block
        2314 * 1E16, // Month 2 : 30 M / 30 / 43200 = 23.14 BZAI/block
        1543 * 1E16, // Month 3 & 4: 20 M / 30 / 43200 = 15.43 BZAI/block
        771 * 1E16, // Month 5 to 12: 10 M / 30 / 43200 = 7.71 BZAI/block
        321 * 1E16 // Month 13 to 24: 50 M / 360 / 43200 = 3.21 BZAI/block
    ];

    uint256 public BZAIPerBlock;
    uint256 public blockStartingMining;

    // UPDATE AUDIT : replace remainingBZAIReward by balanceOf(this)

    PoolInfo public liquidityMining;
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event MiningStart(uint256 startBlock);

    constructor() {
        BZAIPerBlock = BZAIPerBlockAtHalving[0];
    }

    function setTokensAddress(IERC20 _bzai, IERC20 _lpToken)
        external
        onlyOwner
    {
        require(address(_bzai) != address(0), "BZAI Address can't be 0x0");
        require(address(_lpToken) != address(0), "LP Address can't be 0x0");

        require(
            address(BZAI) == address(0) &&
                address(liquidityMining.lpToken) == address(0),
            "Tokens already set!"
        );
        BZAI = _bzai;
        liquidityMining = PoolInfo({
            lpToken: _lpToken,
            lastRewardBlock: 0,
            accBZAIPerShare: 0
        });
    }

    function startMining(uint256 startBlock) external onlyOwner {
        require(liquidityMining.lastRewardBlock == 0, "Mining already started");
        liquidityMining.lastRewardBlock = startBlock;
        blockStartingMining = startBlock;
        emit MiningStart(startBlock);
    }

    function isMiningStarted() external view returns (bool) {
        return liquidityMining.lastRewardBlock == 0;
    }

    function pendingRewards(address _user) external view returns (uint256) {
        require(
            liquidityMining.lastRewardBlock > 0 &&
                block.number >= liquidityMining.lastRewardBlock,
            "Mining not yet started"
        );
        UserInfo storage user = userInfo[_user];
        uint256 accBZAIPerShare = liquidityMining.accBZAIPerShare;
        uint256 lpSupply = liquidityMining.lpToken.balanceOf(address(this));

        if (block.number > liquidityMining.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number - liquidityMining.lastRewardBlock;
            uint256 bzaiReward = multiplier * BZAIPerBlock;
            accBZAIPerShare =
                liquidityMining.accBZAIPerShare +
                ((bzaiReward * 1e12) / lpSupply);
        }
        return
            (user.amount * accBZAIPerShare) /
            1e12 -
            user.rewardDebt +
            user.pendingRewards;
    }

    function updatePool() internal {
        // UPDATE AUDIT : halving
        _checkAndUpdateHalving();

        require(
            liquidityMining.lastRewardBlock > 0 &&
                block.number >= liquidityMining.lastRewardBlock,
            "Mining not yet started"
        );

        uint256 lpSupply = liquidityMining.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            liquidityMining.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - liquidityMining.lastRewardBlock;
        uint256 bzaiReward = multiplier * BZAIPerBlock;
        liquidityMining.accBZAIPerShare =
            liquidityMining.accBZAIPerShare +
            ((bzaiReward * 1e12) / lpSupply);
        liquidityMining.lastRewardBlock = block.number;
    }

    function deposit(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = (user.amount * liquidityMining.accBZAIPerShare) /
                1e12 -
                user.rewardDebt;
            if (pending > 0) {
                user.pendingRewards += pending;
            }
        }
        if (amount > 0) {
            uint256 balanceBefore = liquidityMining.lpToken.balanceOf(
                address(this)
            );
            liquidityMining.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                amount
            );
            uint256 balanceAfter = liquidityMining.lpToken.balanceOf(
                address(this)
            );
            amount = balanceAfter - balanceBefore;
            user.amount += amount;
        }
        user.rewardDebt =
            (user.amount * liquidityMining.accBZAIPerShare) /
            1e12;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "Withdrawing more than you have!");
        updatePool();
        uint256 pending = (user.amount * liquidityMining.accBZAIPerShare) /
            1e12 -
            user.rewardDebt;
        if (pending > 0) {
            user.pendingRewards += pending;
        }
        if (amount > 0) {
            user.amount -= amount;
            liquidityMining.lpToken.safeTransfer(address(msg.sender), amount);
        }
        user.rewardDebt =
            (user.amount * liquidityMining.accBZAIPerShare) /
            1e12;
        emit Withdraw(msg.sender, amount);
    }

    function claim() external {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        uint256 pending = (user.amount * liquidityMining.accBZAIPerShare) /
            1e12 -
            user.rewardDebt;
        if (pending > 0 || user.pendingRewards > 0) {
            uint256 tempPendingReward = user.pendingRewards + pending;
            uint256 claimedAmount = _safeBzaiTransfer(
                msg.sender,
                tempPendingReward
            );

            emit Claim(msg.sender, claimedAmount);
            tempPendingReward -= claimedAmount;
            user.pendingRewards = tempPendingReward;
        }
        user.rewardDebt =
            (user.amount * liquidityMining.accBZAIPerShare) /
            1e12;
    }

    function _safeBzaiTransfer(address to, uint256 amount)
        internal
        returns (uint256)
    {
        uint256 _balance = BZAI.balanceOf(address(this));

        if (amount > _balance) {
            BZAI.safeTransfer(to, _balance);
            return _balance;
        } else {
            BZAI.safeTransfer(to, amount);
            return amount;
        }
    }

    // UPDATE AUDIT : activate halving on J + 30 , J + 60 , J + 120 , J + 360 (where J is starting mining day)
    function _checkAndUpdateHalving() internal {
        if (_halvingNb == 4) {
            if (block.number >= blockStartingMining + (721 * 43200)) {
                BZAIPerBlock = 0;
                return;
            }
            return;
        } else if (_halvingNb == 0) {
            if (block.number >= blockStartingMining + (30 * 43200)) {
                _halvingNb++;
                BZAIPerBlock = BZAIPerBlockAtHalving[1];
                return;
            } else {
                return;
            }
        } else if (_halvingNb == 1) {
            if (block.number >= blockStartingMining + (60 * 43200)) {
                _halvingNb++;
                BZAIPerBlock = BZAIPerBlockAtHalving[2];
                return;
            } else {
                return;
            }
        } else if (_halvingNb == 2) {
            if (block.number >= blockStartingMining + (120 * 43200)) {
                _halvingNb++;
                BZAIPerBlock = BZAIPerBlockAtHalving[3];
                return;
            } else {
                return;
            }
        } else if (_halvingNb == 3) {
            if (block.number >= blockStartingMining + (360 * 43200)) {
                _halvingNb++;
                BZAIPerBlock = BZAIPerBlockAtHalving[4];
                return;
            } else {
                return;
            }
        }
    }
}
