// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WalletDistribution is Ownable {

    IERC20 public BZAI;

    address public _team1;
    address public _team2;

    address public _emergencyTeam1;
    address public _emergencyTeam2;

    address public _futurTeam1;
    address public _futurTeam2;

    uint256 public lastTeamAddressChange;
    bool public pendingChange; 

    uint256 public lastPayment;


    constructor(address _BZAI){
        BZAI = IERC20(_BZAI);
    }

    modifier onlyAuth(){
        require(
            msg.sender == owner() ||
            msg.sender == _team1 ||
            msg.sender == _team2 ||
            msg.sender == _emergencyTeam1 ||
            msg.sender == _emergencyTeam2
            , "Not authorized");
            _;
    }

    function setTeamAddresses(address _team1Addr, address _team2Addr) external onlyAuth{
        require(block.timestamp >= lastTeamAddressChange + 1 days, 'To soon to change again');
        lastTeamAddressChange = block.timestamp;
        pendingChange = true;
        _futurTeam1 = _team1Addr;
        _futurTeam2 = _team2Addr;
    }

    function setEmlergencyAddresses(address _addr1, address _addr2) external onlyAuth{
        require(block.timestamp >= lastTeamAddressChange + 1 days, 'To soon to change again');
        lastTeamAddressChange = block.timestamp;
        pendingChange = true;
        _emergencyTeam1 = _addr1;
        _emergencyTeam2 = _addr2;
    }

    function validateChange() external onlyAuth{
        require(pendingChange, "No change to validate");
        require(block.timestamp >= lastTeamAddressChange + 7 days, "No change to validate");
        lastTeamAddressChange = block.timestamp;
        pendingChange = false;
        _team1 = _futurTeam1;
        _team2 = _futurTeam2;
        _futurTeam1 = address(0x0);
        _futurTeam2 = address(0x0);
    }

    function payOwner() external onlyAuth returns(bool){
        require(!pendingChange, "You have to validate a change");
        require(block.timestamp >= lastPayment + 7 days);
        require(_team1 != address(0x0) && _team2 != address(0x0), "Team address not setted");
        lastPayment = block.timestamp;

        uint256 _toDistribute = BZAI.balanceOf(address(this));

        require(BZAI.transfer(_team1, _toDistribute / 2));
        return(BZAI.transfer(_team2, _toDistribute / 2));

    }

    
}
