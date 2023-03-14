// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Interfaces.sol";

// Main NFT zai/card contract

contract AnimalsFarm is ERC721Enumerable, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("ZAI_FRIENDS", "ZAIF") {}

    IAddresses public gameAddresses;

    string[6] _animals = ["chicken", "bull", "bear", "goat", "shiba", "ape"];

    function setGameAddresses(address _address) external onlyOwner {
        gameAddresses = IAddresses(_address);
    }


    modifier onlyAuth() {
        require(
            gameAddresses.isAuthToManagedNFTs(msg.sender)
            , "Only game allowed");
        _;
    }

    
}
