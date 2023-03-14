// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Interfaces.sol";

// main payment contract
// players rewards/ center revenues... are stored here
// each time a transaction is done in the game, initial contract send BZAI here and attribute balance
// claim rewards will burn 20% of amount
// rewards can be used in game economy without burning taxe
// claim revenues doesn't have burning taxe
// revenues can be used (by burn a part of them) for reserve eggs
// UPDATE AUDIT : totalDebt rise is managed only in payWithRewardsOrWallet when BZAI are transferFrom
contract Payments is Ownable, ReentrancyGuard {
    IBZAI immutable BZAI;

    IAddresses public gameAddresses;
    address public daoAddress;

    uint256 public totalDebt;
    uint256 public feesPercentageForPool = 20; // remaining percentage is burned
    uint256 public percentageForDAO = 0; // at the begining DAO provision is 0% but can be updated later (6 months locking period)

    // each rewards for a Zai will increase his piggyBank . percentage deduce from reward depending on zai's state
    uint256[4] private _zaiPiggyBankFees = [5, 4, 3, 1];

    // there is a 6 months minimum period to unlock DAO fees.
    uint256 public unlockDaoTimestamp;

    mapping(address => uint256) private _myReward;
    mapping(address => uint256) private _myRevenues;
    mapping(uint256 => uint256) private _zaiPiggyBank;

    // UPDATE AUDIT : RewardWon is emitted on Payment contract now
    event RewardWon(
        address indexed user,
        uint256 amount,
        uint256 zaiUsed,
        uint256 amountForPiggyBank,
        bool fromDelegation
    );
    event GameAddressesSetted(address gameAddresses);

    event RewardUsed(
        address indexed user,
        uint256 amountUsed,
        uint256 initialRewardBalanced,
        uint256 amountFromWalletUsed,
        address usedOn
    );
    event RevenuesUsed(
        address indexed user,
        uint256 amountUsed,
        uint256 initialRevenuesBalanced,
        uint256 amountFromWalletUsed,
        address usedOn
    );
    event RevenuesClaimed(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 reward, uint256 burned);
    event BurnedForEggs(address indexed user, uint256 burned);
    event NftOwnerPaid(address indexed owner, uint256 amount);
    event RevenuesForOwner(address indexed user, address from, uint256 amount);
    event FeesDistributed(
        uint256 totalAmount,
        uint256 burned,
        uint256 poolIncrease
    );
    event DaoUpdated(
        address oldDaoAddress,
        address newDaoAddress,
        uint256 oldPercentageFees,
        uint256 newPercentageFees
    );
    event PercentageForPoolChanged(
        uint256 oldPercentage,
        uint256 newPercentage
    );
    event ZaiPiggyBankFeesChanged(uint256[4] oldMetrics, uint256[4] newMetric);
    event ZaiBurned(address user, uint256 zaiId, uint256 amountDelivered);

    constructor(address _BZAI) {
        BZAI = IBZAI(_BZAI);
        unlockDaoTimestamp = block.timestamp + 183 days;
    }

    modifier onlyAuth() {
        require(
            gameAddresses.isAuthToManagedPayments(msg.sender),
            "Not Authorized"
        );
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

    function setFeesPercentageForPool(uint256 _percentage) external onlyOwner {
        require(_percentage <= 100, "Numbers doesn't match");
        uint256 oldMetric = feesPercentageForPool;
        feesPercentageForPool = _percentage;
        emit PercentageForPoolChanged(oldMetric, _percentage);
    }

    function setPercentageForDAO(uint256 _percentage) external onlyOwner {
        require(_percentage <= 100, "Numbers doesn't match");
        require(
            block.timestamp >= unlockDaoTimestamp,
            "locked period is not over"
        );
        uint256 _oldPercentageFees = percentageForDAO;
        percentageForDAO = _percentage;
        emit DaoUpdated(
            daoAddress,
            daoAddress,
            _oldPercentageFees,
            _percentage
        );
    }

    function setDaoAddress(address _dao, uint256 _percentage)
        external
        onlyOwner
    {
        require(_percentage <= 100, "Numbers doesn't match");
        require(
            block.timestamp >= unlockDaoTimestamp,
            "locked period is not over"
        );
        address _oldAddress = daoAddress;
        uint256 _oldPercentage = percentageForDAO;
        daoAddress = _dao;
        percentageForDAO = _percentage;
        emit DaoUpdated(_oldAddress, _dao, _oldPercentage, _percentage);
    }

    function setZaiPiggyBankFees(uint256[4] memory _percentages)
        external
        onlyOwner
    {
        require(
            _percentages[0] <= 10 &&
                _percentages[1] <= 10 &&
                _percentages[2] <= 10 &&
                _percentages[3] <= 10,
            "Percentages too high"
        );
        uint256[4] memory oldMetrics = _zaiPiggyBankFees;
        _zaiPiggyBankFees = _percentages;
        emit ZaiPiggyBankFeesChanged(oldMetrics, _percentages);
    }

    function getZaiPiggyBankFees() external view returns (uint256[4] memory) {
        return _zaiPiggyBankFees;
    }

    function getMyReward(address _user) external view returns (uint256) {
        return _myReward[_user];
    }

    function getMyCentersRevenues(address _user)
        external
        view
        returns (uint256)
    {
        return _myRevenues[_user];
    }

    // UPDATE AUDIT : one function for revenues + rewards
    function getAvailable(address _user) external view returns (uint256) {
        return _myReward[_user] + _myRevenues[_user];
    }

    function getZaiPiggyBank(uint256 _zaiId) external view returns (uint256) {
        return _zaiPiggyBank[_zaiId];
    }

    // UPDATE AUDIT : decrease totalDebt for token quantity who doesn't stay in contract
    function payOwner(address _owner, uint256 _amount)
        external
        onlyAuth
        nonReentrant
        returns (bool)
    {
        uint256 _toOwner = (_amount * 8000) / 10000;
        uint256 _toPool = _amount - _toOwner;
        totalDebt -= _toPool;

        // 80% for owner of Nuresery/Training Center or Forge
        _myRevenues[_owner] += _toOwner;

        uint256 _quarterToPool = _toPool / 4;

        // 5%  for reward challenge in game (daily and weekly ranking)
        require(
            BZAI.transfer(
                gameAddresses.getAddressOf(
                    AddressesInit.Addresses.REWARDS_RANKING
                ),
                _quarterToPool
            )
        );
        _toPool -= _quarterToPool;

        // 5% for winning contract (where each win in game give % of the win pool to the user)
        require(
            BZAI.transfer(
                gameAddresses.getAddressOf(
                    AddressesInit.Addresses.REWARDS_WINNING_PVE
                ),
                _quarterToPool
            )
        );
        _toPool -= _quarterToPool;

        // 5% for pvp pool
        require(
            BZAI.transfer(
                gameAddresses.getAddressOf(AddressesInit.Addresses.REWARDS_PVP),
                _quarterToPool
            )
        );
        _toPool -= _quarterToPool;

        // 5 % for DAO or Burn
        // UPDATE AUDIT : Check if daoAddress != address(0)
        if (percentageForDAO != 0 && daoAddress != address(0)) {
            uint256 _toDAO = (_toPool * percentageForDAO) / 100;
            _toPool -= _toDAO;
            require(BZAI.transfer(daoAddress, _toDAO));
            require(BZAI.burn(_toPool));
        } else {
            require(BZAI.burn(_toPool));
        }

        require(totalDebt <= BZAI.balanceOf(address(this)));

        emit RevenuesForOwner(_owner, msg.sender, _toOwner);

        return true;
    }

    // UPDATE AUDIT : decrease totalDebt for token quantity who doesn't stay in contract
    function distributeFees(uint256 _amount)
        external
        onlyAuth
        nonReentrant
        returns (bool)
    {
        totalDebt -= _amount;
        uint256 _toPool = (_amount * feesPercentageForPool) / 100;
        uint256 _toBurn = _amount - _toPool;

        if (percentageForDAO != 0) {
            uint256 _toDAO = (_toBurn * percentageForDAO) / 100;
            _toBurn -= _toDAO;
            require(BZAI.transfer(daoAddress, _toDAO));
        }

        require(BZAI.burn(_toBurn));

        uint256 _quarterToPool = _toPool / 4;

        // 25%  for reward challenge in game (daily and weekly ranking)
        require(
            BZAI.transfer(
                gameAddresses.getAddressOf(
                    AddressesInit.Addresses.REWARDS_RANKING
                ),
                _quarterToPool
            )
        );
        _toPool -= _quarterToPool;

        // 25% for pvp pool
        require(
            BZAI.transfer(
                gameAddresses.getAddressOf(AddressesInit.Addresses.REWARDS_PVP),
                _quarterToPool
            )
        );
        _toPool -= _quarterToPool;

        emit FeesDistributed(_amount, _toBurn, _toPool * 2);

        // 50% for winning contract (where each win in game give % of the win pool to the user)
        return (
            BZAI.transfer(
                gameAddresses.getAddressOf(
                    AddressesInit.Addresses.REWARDS_WINNING_PVE
                ),
                _toPool
            )
        );
    }

    // UPDATE AUDIT : when less than 20 players played in the ranking, there is a quantity of reward not distributed => we burn them
    function burnUndistributedRewards(uint256 _amount) external returns (bool) {
        require(
            msg.sender ==
                gameAddresses.getAddressOf(AddressesInit.Addresses.RANKING),
            "Not authorized"
        );
        BZAI.burn(_amount);
        return (totalDebt <= BZAI.balanceOf(address(this)));
    }

    // UPDATE AUDIT : decrease totalDebt for token quantity who doesn't stay in contract
    function payNFTOwner(address _owner, uint256 _amount)
        external
        onlyAuth
        nonReentrant
        returns (bool)
    {
        uint256 _toSeller = (_amount * 9800) / 10000;
        uint256 _toDistribute = _amount - _toSeller;
        totalDebt -= _toDistribute;

        // 98% for seller of NFT
        _myRevenues[_owner] += _toSeller;

        uint256 _toBurnOrDAO = _toDistribute / 2;
        _toDistribute -= _toBurnOrDAO;

        // 1 % for DAO or Burn
        if (percentageForDAO != 0) {
            require(BZAI.transfer(daoAddress, _toBurnOrDAO));
        } else {
            require(BZAI.burn(_toBurnOrDAO));
        }

        // prevent round math
        uint256 _toPool1 = _toDistribute / 2;
        _toDistribute -= _toPool1;

        // 0.5%  for reward challenge in game (daily and weekly ranking)
        require(
            BZAI.transfer(
                gameAddresses.getAddressOf(
                    AddressesInit.Addresses.REWARDS_RANKING
                ),
                _toPool1
            )
        );
        // 0.5% for winning contract (where each win in game give 0.1% of the win pool to the user)
        require(
            BZAI.transfer(
                gameAddresses.getAddressOf(
                    AddressesInit.Addresses.REWARDS_WINNING_PVE
                ),
                _toDistribute
            )
        );

        require(totalDebt <= BZAI.balanceOf(address(this)));
        emit NftOwnerPaid(_owner, _toSeller);

        return true;
    }

    // if _zaiId is != 0, we credit to _zaiId a BZAI pool
    function rewardPlayer(
        address _user,
        uint256 _amount,
        uint256 _zaiId,
        uint256 _state,
        bool _isDelegate
    ) external onlyAuth nonReentrant returns (bool) {
        // UPDATE AUDIT : When there is a reward This is the good place where we have to raise the totalDebt
        totalDebt += _amount;
        uint256 _forPiggyBank;
        if (_zaiId != 0) {
            _forPiggyBank = (_amount * _zaiPiggyBankFees[_state]) / 100;
            _zaiPiggyBank[_zaiId] += _forPiggyBank;
            _amount -= _forPiggyBank;
        }

        _myReward[_user] += _amount;
        require(totalDebt <= BZAI.balanceOf(address(this)));
        // UPDATE AUDIT : emit event
        emit RewardWon(_user, _amount, _zaiId, _forPiggyBank, _isDelegate);

        return true;
    }

    function burnRevenuesForEggs(address _owner, uint256 _amount)
        external
        onlyAuth
        nonReentrant
        returns (bool)
    {
        if (_myRevenues[_owner] < _amount) {
            return false;
        } else {
            _myRevenues[_owner] -= _amount;
            totalDebt -= _amount;

            BZAI.burn(_amount);
            require(totalDebt <= BZAI.balanceOf(address(this)));
            emit BurnedForEggs(msg.sender, _amount);
            return true;
        }
    }

    // UPDATE AUDIT : Zai must be free from work/training and delegation
    // ZaiNFT must be approve to payment contract
    function burnZaiToGetHisPiggyBank(uint256 _zaiId) external nonReentrant {
        IZaiNFT Izai = IZaiNFT(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_NFT)
        );
        require(Izai.ownerOf(_zaiId) == msg.sender, "Not your Zai");
        require(Izai.getApproved(_zaiId) == address(this), "Need to approve");

        require(
            !IDelegate(
                gameAddresses.getAddressOf(AddressesInit.Addresses.DELEGATE)
            ).isZaiDelegated(_zaiId),
            "Finish first the delegation process"
        );

        require(
            IZaiMeta(
                gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_META)
            ).isFree(_zaiId),
            "Zai is Not free, finish first his work/training/apprentice"
        );

        uint256 _toSend = _zaiPiggyBank[_zaiId];
        _zaiPiggyBank[_zaiId] = 0;

        emit ZaiBurned(msg.sender, _zaiId, _toSend);
        require(Izai.burnZai(_zaiId));
        require(BZAI.transfer(msg.sender, _toSend));

        totalDebt -= _toSend;
        require(totalDebt <= BZAI.balanceOf(address(this)));
    }

    function claimReward() external nonReentrant returns (bool) {
        require(_myReward[msg.sender] != 0, "No reward to claim");
        uint256 _reward = _myReward[msg.sender];
        _myReward[msg.sender] = 0;
        totalDebt -= _reward;

        uint256 _toBurn = (_reward * 20) / 100;

        require(BZAI.burn(_toBurn));
        require(BZAI.transfer(msg.sender, _reward - _toBurn));
        require(totalDebt <= BZAI.balanceOf(address(this)));

        emit RewardsClaimed(msg.sender, _reward, _toBurn);

        return true;
    }

    function claimMyCentersRevenues() external nonReentrant returns (bool) {
        require(_myRevenues[msg.sender] != 0, "No revenues to claim");
        uint256 _revenues = _myRevenues[msg.sender];
        _myRevenues[msg.sender] = 0;
        totalDebt -= _revenues;

        require(BZAI.transfer(msg.sender, _revenues));
        require(totalDebt <= BZAI.balanceOf(address(this)));

        emit RevenuesClaimed(msg.sender, _revenues);

        return true;
    }

    // User can pay with their pending rewards and/or BZAI balance
    // UPDATE AUDIT : Add initial reward and revenues balance in event
    // UPDATE AUDIT : Simplify algo
    // + optimize gas reducing calling storage (ex: _initialRewardBalance = _myReward[_user])
    function payWithRewardOrWallet(address _user, uint256 _amount)
        external
        onlyAuth
        nonReentrant
        returns (bool)
    {
        uint256 _usedRewards;
        uint256 _usedRevenues;

        uint256 _initialRewardBalance = _myReward[_user];
        uint256 _initialRevenuesBalance = _myRevenues[_user];

        if (_initialRewardBalance == 0 && _initialRevenuesBalance == 0) {
            // if no rewards and no revenues : use BZAI user's balance
            totalDebt += _amount;
            return (BZAI.transferFrom(_user, address(this), _amount));
        } else if (_initialRewardBalance >= _amount) {
            // if rewards are enough to pay :  use _myReward
            _usedRewards = _amount;
            _myReward[_user] -= _amount;
            _amount = 0;
        } else if (_initialRewardBalance != 0) {
            // UPDATE AUDIT : use myReward in priority
            // if got some rewards, but not enough, used it in totality
            _usedRewards = _initialRewardBalance;
            _myReward[_user] = 0;
            _amount -= _usedRewards;
        }

        if (_initialRevenuesBalance >= _amount) {
            // if revenues are enough to pay :  use _myRevenues
            _usedRevenues = _amount;
            _myRevenues[_user] -= _amount;
        } else {
            // if rewards + revenues is not enough to pay, use all rewards and revenue and complete with user's balance
            if (_initialRevenuesBalance != 0) {
                _myRevenues[_user] = 0;
                _usedRevenues = _initialRevenuesBalance;
                _amount -= _usedRevenues;
            }
            totalDebt += _amount;
            require(BZAI.transferFrom(_user, address(this), _amount));
        }

        // emit rewards and revenues used
        // update totaDebt
        if (_usedRewards != 0) {
            emit RewardUsed(
                _user,
                _usedRewards,
                _initialRewardBalance,
                _amount,
                msg.sender
            );
        }
        if (_usedRevenues != 0) {
            emit RevenuesUsed(
                _user,
                _usedRevenues,
                _initialRevenuesBalance,
                _amount,
                msg.sender
            );
        }
        // check totalDebt is ok
        require(totalDebt <= BZAI.balanceOf(address(this)));
        return true;
    }
}
