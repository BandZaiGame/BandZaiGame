// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";

// for futur V2, devs will setup a PvP game mode
// this pool will reward win vs other player
// At the beginning and during at least 6 months, pool won't be active but will receive fees from in game economy
contract RewardsPvP is Ownable {
    IAddresses public gameAddresses;
    address public pvpAddress;
    address public payments;

    IERC20 immutable BZAI;
    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(address pvpAddress, address payments);
    event RewardPortionSetted(
        uint256 lastPortionValue,
        uint256 newPortionValue
    );

    uint256 public rewardPortion = 1000000; // 0.0001%  //1 000 000 => Arround 50 BZAI if pool = 50M

    constructor(address _BZAI) {
        BZAI = IERC20(_BZAI);
    }

    modifier onlyGame() {
        require(msg.sender == pvpAddress, "only Game auth");
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

    function updateInterfaces() external {
        pvpAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.FIGHT_PVP
        );
        payments = gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS);
        emit InterfacesUpdated(pvpAddress, payments);
    }

    function setRewardPortion(uint256 _rewardPortion) external onlyOwner {
        require(
            _rewardPortion >= 10000 && _rewardPortion <= 100000000,
            "Value forbiden"
        );
        uint256 _lastPortion = rewardPortion;
        rewardPortion = _rewardPortion;
        emit RewardPortionSetted(_lastPortion, _rewardPortion);
    }

    function getWinningRewards() external onlyGame returns (uint256) {
        uint256 _toSend = BZAI.balanceOf(address(this)) / rewardPortion;

        require(BZAI.transfer(payments, _toSend));
        return _toSend;
    }
}
