// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// contract for sell NFTs or make offer to NFTs owner
// UPDATE AUDIT : change block by timestamp
// + store end of offer timestamp, not the creating timestamp of offer
contract MarketPlace is Ownable {
    IERC20 immutable BZAI;

    struct OfferDatas {
        address nftOwner;
        address offeredBy;
        address nftAddress;
        uint256 nftId;
        uint256 price;
        uint256 bidValue;
        uint256 offerEndAt;
    }

    uint256 public offerDuration; // in day

    uint256 public offersCount;
    mapping(uint256 => OfferDatas) _offers;
    // UPDATE AUDIT : link NFT to offerId
    mapping(address => mapping(uint256 => uint256)) _nftOfferId;

    IAddresses public gameAddresses;

    event GameAddressesSetted(address gameAddresses);
    event NftSold(
        address indexed nftAddress,
        uint256 offerId,
        uint256 indexed nftId,
        uint256 price,
        address pastOwner,
        address newOwner
    );
    event NftBid(
        address indexed nftAddress,
        address indexed owner,
        address indexed bider,
        uint256 offerId,
        uint256 nftId,
        uint256 price
    );
    event NftInSale(
        address indexed nftAddress,
        address indexed owner,
        uint256 offerId,
        uint256 indexed nftId,
        uint256 price
    );
    event NftSaleCancelled(
        address indexed owner,
        address nftAddress,
        uint256 offerId,
        uint256 indexed nftId,
        uint256 price
    );
    event NftOfferRefused(
        address indexed owner,
        address indexed bider,
        address nftAddress,
        uint256 offerId,
        uint256 indexed nftId,
        uint256 price
    );

    event OfferDurationUpdated(uint256 oldDuration, uint256 newDuration);

    constructor(IERC20 _bzai) {
        BZAI = _bzai;
        offerDuration = 3;
    }

    function setGameAddresses(address _address) external onlyOwner {
        require(
            address(gameAddresses) == address(0x0),
            "game addresses already setted"
        );
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function updateOfferDuration(uint256 _offerDuration) external onlyOwner {
        uint256 oldDuration = offerDuration;
        offerDuration = _offerDuration;
        emit OfferDurationUpdated(oldDuration, _offerDuration);
    }

    function getOffer(uint256 _offerId)
        external
        view
        returns (OfferDatas memory)
    {
        return _offers[_offerId];
    }

    function sellNft(
        address _nftAddress,
        uint256 _nftId,
        uint256 _askedPrice
    ) external {
        IERC721 I = IERC721(_nftAddress);
        require(I.ownerOf(_nftId) == msg.sender, "Not your NFT");
        require(
            I.getApproved(_nftId) == address(this),
            "Need to approve the NFT"
        );
        // UPDATE AUDIT : Not possible to create multiple sale offer for the same NFT
        require(
            _nftOfferId[_nftAddress][_nftId] == 0 ||
                block.timestamp >=
                _offers[_nftOfferId[_nftAddress][_nftId]].offerEndAt,
            "There already is a selling offer for this NFT"
        );
        ++offersCount;
        // UPDATE AUDIT : store Id of offer to NFT
        _nftOfferId[_nftAddress][_nftId] = offersCount;

        OfferDatas storage offer = _offers[offersCount];
        offer.nftAddress = _nftAddress;
        offer.nftId = _nftId;
        offer.nftOwner = msg.sender;
        offer.offerEndAt = block.timestamp + (offerDuration * 1 days);
        offer.price = _askedPrice;

        emit NftInSale(
            _nftAddress,
            msg.sender,
            offersCount,
            _nftId,
            _askedPrice
        );
    }

    function cancelMySell(uint256 _offerId) external {
        OfferDatas memory o = _offers[_offerId];
        require(o.nftOwner == msg.sender, "Not your sale");
        // UPDATE AUDIT : Authorize new owner to create a sale offer for this NFT
        _nftOfferId[o.nftAddress][o.nftId] = 0;

        delete _offers[_offerId];
        emit NftSaleCancelled(
            msg.sender,
            o.nftAddress,
            _offerId,
            o.nftId,
            o.price
        );
    }

    function bidForNft(
        address _nftAddress,
        uint256 _nftId,
        uint256 _bidPrice
    ) external {
        require(
            IERC721(_nftAddress).ownerOf(_nftId) != msg.sender,
            "You can't bid on your own NFT"
        );
        address payment = gameAddresses.getAddressOf(
            AddressesInit.Addresses.PAYMENTS
        );
        // UPDATE AUDIT : only one external call
        uint256 _balance = IPayments(payment).getAvailable(msg.sender);

        if (_balance < _bidPrice) {
            require(
                BZAI.allowance(msg.sender, payment) >= _bidPrice - _balance,
                "You need to approve contract"
            );
            require(
                BZAI.balanceOf(msg.sender) >= _bidPrice - _balance,
                "You don't have enough BZAI"
            );
        }

        ++offersCount;
        OfferDatas storage offer = _offers[offersCount];
        offer.nftAddress = _nftAddress;
        offer.offeredBy = msg.sender;
        offer.nftId = _nftId;
        offer.nftOwner = IERC721(_nftAddress).ownerOf(_nftId);
        offer.offerEndAt = block.timestamp + (offerDuration * 1 days);
        offer.bidValue = _bidPrice;

        emit NftBid(
            _nftAddress,
            offer.nftOwner,
            msg.sender,
            offersCount,
            _nftId,
            _bidPrice
        );
    }

    function refuseOffer(uint256 _offerId) external {
        OfferDatas memory offer = _offers[_offerId];
        require(offer.nftOwner == msg.sender, "not your NFT");

        delete _offers[_offerId];

        emit NftOfferRefused(
            offer.nftOwner,
            offer.offeredBy,
            offer.nftAddress,
            _offerId,
            offer.nftId,
            offer.price
        );
    }

    function cancelMyBid(uint256 _offerId) external {
        require(_offers[_offerId].offeredBy == msg.sender, "Not your offer");
        delete _offers[_offerId];
    }

    function acceptBid(uint256 _offerId) external {
        OfferDatas memory offer = _offers[_offerId];
        require(offer.nftOwner == msg.sender, "not your NFT");
        address payments = gameAddresses.getAddressOf(
            AddressesInit.Addresses.PAYMENTS
        );
        IPayments IPay = IPayments(payments);

        require(
            block.timestamp <= offer.offerEndAt,
            string(
                abi.encodePacked("Offers only avalaible", offerDuration, "days")
            )
        );

        delete _offers[_offerId];

        require(
            IPay.payWithRewardOrWallet(offer.offeredBy, offer.bidValue),
            "bidder hasn't enough founds"
        );
        IPay.payNFTOwner(msg.sender, offer.bidValue);

        IERC721(offer.nftAddress).transferFrom(
            msg.sender,
            offer.offeredBy,
            offer.nftId
        );

        emit NftSold(
            offer.nftAddress,
            _offerId,
            offer.nftId,
            offer.bidValue,
            msg.sender,
            offer.offeredBy
        );
    }

    function buyNft(uint256 _offerId) external {
        OfferDatas memory offer = _offers[_offerId];
        require(
            offer.nftOwner == IERC721(offer.nftAddress).ownerOf(offer.nftId),
            "owner change offer not available"
        );
        require(
            block.timestamp <= offer.offerEndAt,
            string(
                abi.encodePacked("Offers only avalaible", offerDuration, "days")
            )
        );

        IPayments IPay = IPayments(
            gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
        );
        require(IPay.payWithRewardOrWallet(msg.sender, offer.price));

        IPay.payNFTOwner(offer.nftOwner, offer.price);

        address _from = offer.nftOwner;
        uint256 _tokenId = offer.nftId;
        delete _offers[_offerId];

        // UPDATE AUDIT : Authorize new owner to create a sale offer for this NFT
        _nftOfferId[offer.nftAddress][offer.nftId] = 0;

        IERC721(offer.nftAddress).transferFrom(_from, msg.sender, _tokenId);

        emit NftSold(
            offer.nftAddress,
            _offerId,
            offer.nftId,
            offer.price,
            offer.nftOwner,
            msg.sender
        );
    }
}
