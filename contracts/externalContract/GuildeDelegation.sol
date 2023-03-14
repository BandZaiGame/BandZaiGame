// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GuildeDelegation is Ownable, ERC721Holder {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 private _platformFees = 5;

    mapping(address => mapping(address => EnumerableSet.UintSet))
        private _scholarsNFTs;
    mapping(address => mapping(address => EnumerableSet.UintSet))
        private _guildeNFTs;

    struct GuildeDatas {
        address renterOf;
        address masterOf;
        address platformAddress;
        uint256 percentageForScholar;
        uint256 percentageForGuilde;
        uint256 percentagePlatformFees;
    }

    mapping(address => mapping(uint256 => GuildeDatas)) private _guildeDatas;

    event NewGuildeNft(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed guildeAddress
    );

    event DeletedGuildeNft(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed guildeAddress
    );

    event NftRented(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed renter,
        uint256 percentageForRenter
    );
    event RentingChanged(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed renter,
        uint256 percentageForRenter
    );
    event EndRenting(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed scholar
    );

    event PlatformFeesChanged(uint256 oldMetric, uint256 newMetric);

    function setPlatformFees(uint256 _fees) external onlyOwner {
        require(_fees <= 20, "Fees can't be more than 20%");
        uint256 oldMetric = _platformFees;
        _platformFees = _fees;
        emit PlatformFeesChanged(oldMetric, _fees);
    }

    function getRentingDatas(address _nftAddress, uint256 _tokenId)
        external
        view
        returns (GuildeDatas memory)
    {
        return _guildeDatas[_nftAddress][_tokenId];
    }

    function delegateNFTs(
        address _nftAddress,
        uint256[] calldata _ids,
        address[] calldata _scholars,
        uint256 _percentageForScholars
    ) external returns (bool) {
        require(
            _percentageForScholars > 0 &&
                _percentageForScholars <= 100 - _platformFees,
            "Bad percentage"
        );
        require(
            _ids.length == _scholars.length,
            "Issue in _ids or _scholars lengths"
        );
        for (uint256 i = 0; i < _ids.length; ) {
            // transfer NFT in smart contract
            IERC721(_nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _ids[i]
            );
            // add NFT to guilde balance
            _guildeNFTs[msg.sender][_nftAddress].add(_ids[i]);
            // add NFT to scholar permission
            _scholarsNFTs[_scholars[i]][_nftAddress].add(_ids[i]);

            GuildeDatas storage g = _guildeDatas[_nftAddress][_ids[i]];
            g.masterOf = msg.sender;
            g.renterOf = _scholars[i];
            g.platformAddress = owner();
            g.percentageForScholar = _percentageForScholars;
            g.percentageForGuilde =
                100 -
                _percentageForScholars -
                _platformFees;
            g.percentagePlatformFees = _platformFees;

            emit NftRented(
                _nftAddress,
                _ids[i],
                _scholars[i],
                _percentageForScholars
            );

            emit NewGuildeNft(_nftAddress, _ids[i], msg.sender);

            unchecked {
                ++i;
            }
        }
        return true;
    }

    function modifyPermissions(
        address _nftAddress,
        uint256[] calldata _ids,
        address[] calldata _scholars,
        uint256 _percentageForScholars
    ) external returns (bool) {
        require(
            _percentageForScholars > 0 &&
                _percentageForScholars < 100 - _platformFees,
            "Bad percentage"
        );
        require(
            _ids.length == _scholars.length,
            "Issue in _ids or _scholars lengths"
        );
        for (uint256 i = 0; i < _ids.length; ) {
            require(
                _guildeNFTs[msg.sender][_nftAddress].contains(_ids[i]),
                "Not a NFT managed by msg.sender"
            );
            // remove previously renter
            GuildeDatas storage g = _guildeDatas[_nftAddress][_ids[i]];
            if (g.renterOf != address(0x0)) {
                _scholarsNFTs[g.renterOf][_nftAddress].remove(_ids[i]);
            }
            // add NFT to scholar permission
            _scholarsNFTs[_scholars[i]][_nftAddress].add(_ids[i]);
            // associate tokenId to scholar address
            g.masterOf = msg.sender;
            g.renterOf = _scholars[i];
            g.percentageForScholar = _percentageForScholars;
            g.percentageForGuilde =
                100 -
                _percentageForScholars -
                _platformFees;
            g.percentagePlatformFees = _platformFees;
            emit RentingChanged(
                _nftAddress,
                _ids[i],
                _scholars[i],
                _percentageForScholars
            );

            unchecked {
                ++i;
            }
        }
        return true;
    }

    function getScholarNFTs(
        address _nftAddress,
        address _scholar,
        uint256 _startIndex,
        uint256 _quantity
    ) external view returns (uint256[] memory) {
        return _getScholarNFTs(_nftAddress, _scholar, _startIndex, _quantity);
    }

    function _getScholarNFTs(
        address _nftAddress,
        address _scholar,
        uint256 _startIndex,
        uint256 _quantity
    ) internal view returns (uint256[] memory list) {
        uint256 _balance = _scholarsNFTs[_scholar][_nftAddress].length();
        if (_balance > 0) {
            if (_balance <= _quantity) {
                list = new uint256[](_balance);
                for (uint256 i = 0; i < _balance; ) {
                    uint256 _tokenId = _scholarsNFTs[_scholar][_nftAddress].at(
                        i
                    );
                    list[i] = _tokenId;

                    unchecked {
                        ++i;
                    }
                }
            } else if (_startIndex + _quantity > _balance) {
                list = new uint256[](_quantity);
                for (uint256 i = _startIndex; i < _balance; ) {
                    uint256 _tokenId = _scholarsNFTs[_scholar][_nftAddress].at(
                        i
                    );
                    list[i - _startIndex] = _tokenId;
                    unchecked {
                        ++i;
                    }
                }
            } else {
                list = new uint256[](_balance);

                for (uint256 i = 0; i < _quantity; ) {
                    uint256 _tokenId = _scholarsNFTs[_scholar][_nftAddress].at(
                        _startIndex
                    );
                    list[i] = _tokenId;

                    unchecked {
                        ++i;
                        ++_startIndex;
                    }
                }
            }
        }
    }

    function getGuildNFTs(
        address _nftAddress,
        address _guild,
        uint256 _startIndex,
        uint256 _quantity
    ) external view returns (uint256[] memory) {
        return _getGuildNFTs(_nftAddress, _guild, _startIndex, _quantity);
    }

    // UPDATE AUDIT : add _startIndex and LimitQ
    function _getGuildNFTs(
        address _nftAddress,
        address _guild,
        uint256 _startIndex,
        uint256 _quantity
    ) internal view returns (uint256[] memory) {
        uint256 _balance = _guildeNFTs[_guild][_nftAddress].length();
        uint256[] memory _list;
        if (_balance > 0) {
            if (_balance <= _quantity) {
                _list = new uint256[](_balance);
                for (uint256 i = 0; i < _balance; ) {
                    uint256 _tokenId = _guildeNFTs[_guild][_nftAddress].at(i);
                    _list[i] = _tokenId;

                    unchecked {
                        ++i;
                    }
                }
            } else if (_startIndex + _quantity > _balance) {
                _list = new uint256[](_quantity);
                for (uint256 i = _startIndex; i < _balance; ) {
                    uint256 _tokenId = _guildeNFTs[_guild][_nftAddress].at(i);
                    _list[i - _startIndex] = _tokenId;
                    unchecked {
                        ++i;
                    }
                }
            } else {
                _list = new uint256[](_balance);

                for (uint256 i = 0; i < _quantity; ) {
                    uint256 _tokenId = _guildeNFTs[_guild][_nftAddress].at(i);

                    _list[i] = _tokenId;

                    unchecked {
                        ++i;
                        ++_startIndex;
                    }
                }
            }
        }
        return _list;
    }

    function kickScholar(
        address _nftAddress,
        address _scholar,
        uint256 _startIndex,
        uint256 _max
    ) external returns (bool) {
        uint256[] memory _list = _getScholarNFTs(
            _nftAddress,
            _scholar,
            _startIndex,
            _max
        );

        for (uint256 i = 0; i < _list.length; ) {
            if (_guildeNFTs[msg.sender][_nftAddress].contains(_list[i])) {
                // remove NFT to scholar permission
                _scholarsNFTs[_scholar][_nftAddress].remove(_list[i]);
                // remove association tokenId to scholar address
                _guildeDatas[_nftAddress][_list[i]].renterOf = address(0x0);
            }

            emit EndRenting(_nftAddress, _list[i], _scholar);

            unchecked {
                ++i;
            }
        }
        return true;
    }

    function withdrawAllNft(address _nftAddress, uint256 _limitQuantity)
        external
        returns (bool)
    {
        uint256[] memory _list = _getGuildNFTs(
            _nftAddress,
            msg.sender,
            0,
            _limitQuantity
        );
        if (_list.length > 0) {
            for (uint256 i = 0; i < _list.length; ) {
                require(_withdrawNft(msg.sender, _nftAddress, _list[i]));

                unchecked {
                    ++i;
                }
            }
        }
        return true;
    }

    function withdrawNft(address _nftAddress, uint256 _tokenId)
        external
        returns (bool)
    {
        return _withdrawNft(msg.sender, _nftAddress, _tokenId);
    }

    function _withdrawNft(
        address _guildAddress,
        address _nftAddress,
        uint256 _tokenId
    ) internal returns (bool) {
        require(
            _guildeNFTs[_guildAddress][_nftAddress].contains(_tokenId),
            "Not a token managed by msg.sender"
        );
        _guildeNFTs[_guildAddress][_nftAddress].remove(_tokenId);
        // remove old scholar
        address _scholar = _guildeDatas[_nftAddress][_tokenId].renterOf;
        if (_scholar != address(0x0)) {
            _scholarsNFTs[_scholar][_nftAddress].remove(_tokenId);
        }
        emit DeletedGuildeNft(_nftAddress, _tokenId, _guildAddress);
        delete _guildeDatas[_nftAddress][_tokenId];

        // withdraw NFT from smart contract
        IERC721(_nftAddress).safeTransferFrom(
            address(this),
            _guildAddress,
            _tokenId
        );
        return true;
    }

    function withdrawTokens(address _tokenAddress)
        external
        onlyOwner
        returns (bool)
    {
        uint256 _balance = IERC20(_tokenAddress).balanceOf(address(this));
        return (IERC20(_tokenAddress).transfer(msg.sender, _balance));
    }
}
