// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestedWallet2 is Ownable {
    IERC20 public BZAI;

    constructor(address _BZAI, address _walletOwner) {
        BZAI = IERC20(_BZAI);
        walletOwner = _walletOwner;
    }

    address public walletOwner;
    uint256 public tgeTimestamp;

    uint256[6] public vestingAmount = [
        10_000_000 * 1E18,
        10_000_000 * 1E18,
        10_000_000 * 1E18,
        10_000_000 * 1E18,
        10_000_000 * 1E18,
        10_000_000 * 1E18
    ];

    uint256[6] _vestingTimestamps;

    modifier onlyWalletOwner() {
        require(msg.sender == walletOwner, "only wallet owner allowed");
        _;
    }

    function getAddressTotalAlloc() external view returns (uint256) {
        return (vestingAmount[0] +
            vestingAmount[1] +
            vestingAmount[2] +
            vestingAmount[3] +
            vestingAmount[4] +
            vestingAmount[5]);
    }

    function getVestingTimestamp()
        external
        view
        returns (uint256[6] memory vestingTimestamps)
    {
        return _vestingTimestamps;
    }

    function setTge(uint256 _timestamp) external onlyOwner {
        require(
            tgeTimestamp == 0 || tgeTimestamp > block.timestamp,
            "Can't set after TGE timestamp"
        );
        require(_timestamp > block.timestamp, "TGE can't be in past time");

        tgeTimestamp = _timestamp;
        uint256 toAdd = 30 days;

        _vestingTimestamps[0] = _timestamp + (toAdd * 6);

        for (uint256 i = 1; i < 6; ) {
            _vestingTimestamps[i] = _vestingTimestamps[0] + (i * toAdd);
            unchecked {
                ++i;
            }
        }
    }

    function withdraw() external onlyWalletOwner {
        require(tgeTimestamp != 0, "tge not set");
        require(block.timestamp >= tgeTimestamp, "Too soon !");
        uint256 _unlocked;
        for (uint256 i; i < 6; ) {
            if (block.timestamp >= _vestingTimestamps[i]) {
                _unlocked += vestingAmount[i];
                vestingAmount[i] = 0;
            }
            unchecked {
                ++i;
            }
        }
        require(_unlocked != 0, "Nothing to withdraw");
        require(BZAI.transfer(walletOwner, _unlocked));
    }

    function emergencyWithdraw(IERC20 _token) external onlyWalletOwner {
        require(
            block.timestamp >= _vestingTimestamps[5] || _token != BZAI,
            "Too soon !"
        );
        require(_token.transfer(walletOwner, _token.balanceOf(address(this))));
    }
}
