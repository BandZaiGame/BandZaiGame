// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Interfaces.sol";

// UPDATE AUDIT : add totalSupply() method

contract Nursery is ERC721, Ownable {
    uint256 _totalSupply;
    string _CID;

    constructor(
        uint256 _preMint,
        address _NFTreserve,
        string memory _Cid
    ) ERC721("Nursery_NFT", "NURS") {
        _totalSupply = _preMint;
        _CID = _Cid;
        for (uint256 i = 1; i <= _preMint; ) {
            _safeMint(_NFTreserve, i);

            unchecked {
                ++i;
            }
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "https://ipfs.io/ipfs/",
                    _CID,
                    "/",
                    tokenId,
                    ".json"
                )
            );
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
}
