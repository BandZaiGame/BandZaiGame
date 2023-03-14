// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// Contract allow owner of NFT to claim Nurseries/Training centers / Laboratories and Tickets
contract ClaimNFTs is Ownable, ERC721Holder {
    using EnumerableSet for EnumerableSet.UintSet;

    IERC721 public nursery;
    IERC721 public trainingCenter;
    IERC721 public laboratory;
    IERC721 public ticket;

    mapping(uint256 => address) _nurseryOwner;
    mapping(uint256 => address) _trainingOwner;
    mapping(uint256 => address) _laboratoryOwner;
    mapping(uint256 => address) _ticketOwner;

    mapping(address => EnumerableSet.UintSet) myNurseries;
    mapping(address => EnumerableSet.UintSet) myTrainings;
    mapping(address => EnumerableSet.UintSet) myLaboratories;
    mapping(address => EnumerableSet.UintSet) myTickets;

    event OwnerSetted(
        string indexed NftType,
        address indexed futurOwner,
        uint256 indexed tokenId
    );
    event NftSetted(
        address nursery,
        address trainingCenter,
        address laboratory,
        address ticket
    );

    function setNFTs(
        address _nursery,
        address _training,
        address _labo,
        address _ticket
    ) external onlyOwner {
        require(_nursery != address(0x0), "nursery address can't be 0x0");
        require(
            _training != address(0x0),
            "training center address can't be 0x0"
        );
        require(_labo != address(0x0), "laboratory address can't be 0x0");
        require(_ticket != address(0x0), "ticket address can't be 0x0");

        nursery = IERC721(_nursery);
        trainingCenter = IERC721(_training);
        laboratory = IERC721(_labo);
        ticket = IERC721(_ticket);
        emit NftSetted(_nursery, _training, _labo, _ticket);
    }

    // Owner of contract can attribute a NFT to an Address
    function setNurseryOwner(uint256 _tokenId, address _user)
        external
        onlyOwner
    {
        // need this NFT to be in the smart contract
        require(
            nursery.ownerOf(_tokenId) == address(this),
            "NFT not on this smart contract"
        );
        // if NFT already atributed, update it
        if (_nurseryOwner[_tokenId] != address(0x0)) {
            myNurseries[_nurseryOwner[_tokenId]].remove(_tokenId);
        }
        _nurseryOwner[_tokenId] = _user;
        myNurseries[_user].add(_tokenId);
        emit OwnerSetted("Nursery", _user, _tokenId);
    }

    function setTrainingOwner(uint256 _tokenId, address _user)
        external
        onlyOwner
    {
        require(
            trainingCenter.ownerOf(_tokenId) == address(this),
            "NFT not on this smart contract"
        );
        if (_trainingOwner[_tokenId] != address(0x0)) {
            myTrainings[_trainingOwner[_tokenId]].remove(_tokenId);
        }
        _trainingOwner[_tokenId] = _user;
        myTrainings[_user].add(_tokenId);
        emit OwnerSetted("Training", _user, _tokenId);
    }

    function setLaboratoryOwner(uint256 _tokenId, address _user)
        external
        onlyOwner
    {
        require(
            laboratory.ownerOf(_tokenId) == address(this),
            "NFT not on this smart contract"
        );
        if (_laboratoryOwner[_tokenId] != address(0x0)) {
            myLaboratories[_laboratoryOwner[_tokenId]].remove(_tokenId);
        }
        _laboratoryOwner[_tokenId] = _user;
        myLaboratories[_user].add(_tokenId);
        emit OwnerSetted("Laboratory", _user, _tokenId);
    }

    function setTicketOwner(uint256 _tokenId, address _user)
        external
        onlyOwner
    {
        require(
            ticket.ownerOf(_tokenId) == address(this),
            "NFT not on this smart contract"
        );
        if (_ticketOwner[_tokenId] != address(0x0)) {
            myTickets[_ticketOwner[_tokenId]].remove(_tokenId);
        }
        _ticketOwner[_tokenId] = _user;
        myTickets[_user].add(_tokenId);
        emit OwnerSetted("Ticket", _user, _tokenId);
    }

    // return list of NFTs user can claim
    function getWhatCanUserClaim(address _user)
        external
        view
        returns (
            uint256[] memory nurseries,
            uint256[] memory laboratories,
            uint256[] memory trainings,
            uint256[] memory tickets
        )
    {
        return _getWhatCanUserClaim(_user);
    }

    function _getWhatCanUserClaim(address _user)
        internal
        view
        returns (
            uint256[] memory nurseries,
            uint256[] memory laboratories,
            uint256[] memory trainings,
            uint256[] memory tickets
        )
    {
        uint256[] memory _nurseries = new uint256[](
            myNurseries[_user].length()
        );
        uint256[] memory _laboratories = new uint256[](
            myLaboratories[_user].length()
        );
        uint256[] memory _trainings = new uint256[](
            myTrainings[_user].length()
        );
        uint256[] memory _tickets = new uint256[](myTickets[_user].length());

        for (uint256 i; i < _nurseries.length; ) {
            _nurseries[i] = myNurseries[_user].at(i);
            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < _laboratories.length; ) {
            _laboratories[i] = myLaboratories[_user].at(i);
            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < _trainings.length; ) {
            _trainings[i] = myTrainings[_user].at(i);
            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < _tickets.length; ) {
            _tickets[i] = myTickets[_user].at(i);
            unchecked {
                ++i;
            }
        }

        return (_nurseries, _laboratories, _trainings, _tickets);
    }

    function claimAllNFTs() external {
        (
            uint256[] memory nurseries,
            uint256[] memory laboratories,
            uint256[] memory trainings,
            uint256[] memory tickets
        ) = _getWhatCanUserClaim(msg.sender);
        require(
            nurseries.length != 0 ||
                laboratories.length != 0 ||
                trainings.length != 0 ||
                tickets.length != 0,
            "Nothing to claim"
        );

        if (nurseries.length != 0) {
            for (
                uint256 i;
                i < (nurseries.length > 2 ? 2 : nurseries.length);

            ) {
                myNurseries[msg.sender].remove(nurseries[i]);
                nursery.safeTransferFrom(
                    address(this),
                    msg.sender,
                    nurseries[i]
                );
                unchecked {
                    ++i;
                }
            }
        }

        if (laboratories.length != 0) {
            for (
                uint256 i;
                i < (laboratories.length > 2 ? 2 : laboratories.length);

            ) {
                myLaboratories[msg.sender].remove(laboratories[i]);
                laboratory.safeTransferFrom(
                    address(this),
                    msg.sender,
                    laboratories[i]
                );
                unchecked {
                    ++i;
                }
            }
        }

        if (trainings.length != 0) {
            for (
                uint256 i;
                i < (trainings.length > 2 ? 2 : trainings.length);

            ) {
                myTrainings[msg.sender].remove(trainings[i]);
                trainingCenter.safeTransferFrom(
                    address(this),
                    msg.sender,
                    trainings[i]
                );
                unchecked {
                    ++i;
                }
            }
        }

        if (tickets.length != 0) {
            for (uint256 i; i < (tickets.length > 2 ? 2 : tickets.length); ) {
                myTickets[msg.sender].remove(tickets[i]);
                ticket.safeTransferFrom(address(this), msg.sender, tickets[i]);
                unchecked {
                    ++i;
                }
            }
        }
    }

    // tickets will be give away to user on different marketing promotions
    function claimTickets() external {
        (, , , uint256[] memory tickets) = _getWhatCanUserClaim(msg.sender);

        if (tickets.length != 0) {
            for (uint256 i; i < (tickets.length > 6 ? 6 : tickets.length); ) {
                myTickets[msg.sender].remove(tickets[i]);
                ticket.safeTransferFrom(address(this), msg.sender, tickets[i]);
                unchecked {
                    ++i;
                }
            }
        }
    }
}
