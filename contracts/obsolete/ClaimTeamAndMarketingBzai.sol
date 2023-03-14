// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ClaimTeamAndMarketingBzai is Ownable, ReentrancyGuard {
    IERC20 public BZAI;
    uint256 public assigned;
    uint256 constant _blockEvery = 2; // block every 2 seconds on polygon mainnet

    uint256 public tgeUnlockedBlock;

    mapping(address => uint256[6]) _teamVestingAmount;
    mapping(address => uint256[6]) _marketingVestingAmount;

    uint256[6] _teamVestingBlock;
    uint256[6] _marketingVestingBlock;

    event Claimed(address indexed user, string vestingType, uint256 amount);
    event TgeSetted(uint256 TgeBlock);
    event AllocReseted(address indexed user, uint256 amount);

    constructor(address _BZAI) {
        BZAI = IERC20(_BZAI);
    }

    function getAddressAllocs(address _user)
        external
        view
        returns (
            uint256[6] memory teamVesting,
            uint256[6] memory marketingVesting
        )
    {
        return (_teamVestingAmount[_user], _marketingVestingAmount[_user]);
    }

    function resetAlloc(address _user) external onlyOwner {
        uint256 toReset;
        for (uint256 i; i < 6; ) {
            toReset += _teamVestingAmount[_user][i];
            toReset += _marketingVestingAmount[_user][i];
            unchecked {
                ++i;
            }
        }
        delete _teamVestingAmount[_user];
        delete _marketingVestingAmount[_user];
        assigned -= toReset;
        emit AllocReseted(_user, toReset);
    }

    function setTgeBlock(uint256 _block) external onlyOwner {
        require(
            tgeUnlockedBlock == 0 || tgeUnlockedBlock > block.number,
            "Can't set after TGE block"
        );
        require(_block > block.number, "TGE can't be in past time");

        tgeUnlockedBlock = _block;
        uint256 toAdd = (86400 * 30) / _blockEvery;

        _marketingVestingBlock[0] = _block + toAdd;
        _teamVestingBlock[0] = _block + (toAdd * 6);

        for (uint256 i = 1; i < 6; ) {
            _marketingVestingBlock[i] = _marketingVestingBlock[0] + (i * toAdd);
            _teamVestingBlock[i] = _teamVestingBlock[0] + (i * toAdd);
            unchecked {
                ++i;
            }
        }
        emit TgeSetted(_block);
    }

    function setTeamVesting(address _user, uint256 _amount) external onlyOwner {
        uint256 _toReduce;
        for (uint256 i; i < 6; ) {
            if (_teamVestingAmount[_user][i] != 0) {
                _toReduce += _teamVestingAmount[_user][i];
                _teamVestingAmount[_user][i] = 0;
            }
            unchecked {
                ++i;
            }
        }
        if (_toReduce != 0) {
            assigned -= _toReduce;
        }

        require(
            BZAI.balanceOf(address(this)) >= assigned + _amount,
            "Too much assigned"
        );
        assigned += _amount;

        uint256 claimablePart = _amount / 6;
        uint256 modulo = _amount % 6;

        for (uint256 i; i < 6; ) {
            _teamVestingAmount[_user][i] = claimablePart;
            if (i == 5) {
                _teamVestingAmount[_user][i] += modulo;
            }
            unchecked {
                ++i;
            }
        }
    }

    function setMarketingVesting(address _user, uint256 _amount)
        external
        onlyOwner
    {
        uint256 _toReduce;
        for (uint256 i; i < 6; ) {
            if (_marketingVestingAmount[_user][i] != 0) {
                _toReduce += _marketingVestingAmount[_user][i];
                _marketingVestingAmount[_user][i] = 0;
            }
            unchecked {
                ++i;
            }
        }
        if (_toReduce != 0) {
            assigned -= _toReduce;
        }

        require(
            BZAI.balanceOf(address(this)) >= assigned + _amount,
            "Too much assigned"
        );
        assigned += _amount;

        uint256 claimablePart = _amount / 6;
        uint256 modulo = _amount % 6;

        for (uint256 i; i < 6; ) {
            _marketingVestingAmount[_user][i] = claimablePart;
            if (i == 5) {
                _marketingVestingAmount[_user][i] += modulo;
            }
            unchecked {
                ++i;
            }
        }
    }

    function getMarketingClaimable(address _user)
        external
        view
        returns (uint256)
    {
        return _getMarketingClaimable(_user);
    }

    function _getMarketingClaimable(address _user)
        internal
        view
        returns (uint256)
    {
        uint256 _claimable;
        for (uint256 i; i < 6; ) {
            if (block.number >= _marketingVestingBlock[i]) {
                _claimable += _marketingVestingAmount[_user][i];
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }
        return _claimable;
    }

    function getTeamClaimable(address _user) external view returns (uint256) {
        return _getTeamClaimable(_user);
    }

    function _getTeamClaimable(address _user) internal view returns (uint256) {
        uint256 _claimable;
        for (uint256 i; i < 6; ) {
            if (block.number >= _teamVestingBlock[i]) {
                _claimable += _teamVestingAmount[_user][i];
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }
        return _claimable;
    }

    function _cleanMarketingClaimable(address _user)
        internal
        returns (uint256)
    {
        uint256 _cleaned;
        for (uint256 i; i < 6; ) {
            if (block.number >= _marketingVestingBlock[i]) {
                _cleaned += _marketingVestingAmount[_user][i];
                _marketingVestingAmount[_user][i] = 0;
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit Claimed(_user, "marketing", _cleaned);

        return _cleaned;
    }

    function _cleanTeamClaimable(address _user) internal returns (uint256) {
        uint256 _cleaned;
        for (uint256 i; i < 6; ) {
            if (block.number >= _teamVestingBlock[i]) {
                _cleaned += _teamVestingAmount[_user][i];
                _teamVestingAmount[_user][i] = 0;
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit Claimed(_user, "team", _cleaned);

        return _cleaned;
    }

    function claimMarketingBZAIs() external nonReentrant {
        require(tgeUnlockedBlock != 0, "tge not set");
        require(block.number >= tgeUnlockedBlock, "Too soon !");

        uint256 _cleaned = _cleanMarketingClaimable(msg.sender);

        assigned -= _cleaned;

        require(assigned <= BZAI.balanceOf(address(this)));
        require(BZAI.transfer(msg.sender, _cleaned));
    }

    function claimTeamBZAIs() external nonReentrant {
        require(tgeUnlockedBlock != 0, "tge not set");
        require(block.number >= tgeUnlockedBlock, "Too soon !");

        uint256 _cleaned = _cleanTeamClaimable(msg.sender);

        assigned -= _cleaned;

        require(assigned <= BZAI.balanceOf(address(this)));
        require(BZAI.transfer(msg.sender, _cleaned));
    }
}
