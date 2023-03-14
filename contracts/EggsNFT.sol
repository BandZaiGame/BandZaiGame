// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Interfaces.sol";

// eggs are minted by Nurseries.
// An egg got maturity date before scratch
// An owner of a chicken can cover an egg for reduce the maturity period
// UPDATE AUDIT : add totalSupply() method

contract EggsNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 _totalSupply;

    IAddresses public gameAddresses;

    // UPDATE AUDIT : struct egg
    struct Egg {
        uint8 state;
        uint32 maturityTimestamp;
        uint256 isCoverBy;
    }

    mapping(uint256 => Egg) private _egg;

    mapping(uint256 => bool) _chickenBusy;

    uint256 _hourAccelarationPrice = 10 * 1E18;

    event GameAddressesSetted(address gameAddresses);
    event EggScratched(uint256 indexed state, uint256 zaiId, address owner);
    event AccelerationPriceChanged(uint256 oldPrice, uint256 newPrice);
    event MaturitiesUpdated(
        uint256 indexed tokenId,
        uint256 oldMaturity,
        uint256 newMaturity
    );

    constructor() ERC721("Eggs_Banzai_NFT", "EGGS") {}

    modifier onlyAuth() {
        require(
            gameAddresses.isAuthToManagedNFTs(msg.sender),
            "Only game allowed"
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

    function setHourAccelerationPrice(uint256 _price) external onlyOwner {
        uint256 _lastPrice = _hourAccelarationPrice;
        _hourAccelarationPrice = _price;
        emit AccelerationPriceChanged(_lastPrice, _price);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function getEgg(uint256 _tokenId) external view returns (Egg memory) {
        return _egg[_tokenId];
    }

    // UPDATE AUDIT : add view for chicken busy
    function chickenBusy(uint256 _chickenId) external view returns (bool) {
        return _chickenBusy[_chickenId];
    }

    function mintEgg(
        address _to,
        uint256 _state,
        uint256 _maturityDuration
    ) external onlyAuth returns (uint256) {
        _tokenIds.increment();
        uint256 _newItemId = _tokenIds.current();
        _totalSupply++;
        Egg storage e = _egg[_newItemId];
        e.state = uint8(_state);
        e.maturityTimestamp = uint32(block.timestamp + _maturityDuration);
        _safeMint(_to, _newItemId);

        return (_newItemId);
    }

    function isMature(uint256 _tokenId) external view returns (bool) {
        return _isMature(_tokenId);
    }

    function _isMature(uint256 _tokenId) internal view returns (bool) {
        uint256 _maturity = _egg[_tokenId].maturityTimestamp;
        if (_maturity != 0) {
            return block.timestamp >= _maturity;
        } else {
            return false;
        }
    }

    function claimMatureZai(uint256 _tokenId, string memory _zaiName)
        external
        returns (uint256)
    {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");
        require(msg.sender == ownerOf(_tokenId), "Not yours");
        require(_isMature(_tokenId), "Maturity not finished");
        Egg memory e = _egg[_tokenId];
        if (e.isCoverBy != 0) {
            _chickenBusy[e.isCoverBy] = false;
        }

        _totalSupply--;
        _burn(_tokenId);
        delete _egg[_tokenId];

        uint256 _zaiId = _generateRandomZai(_zaiName, msg.sender, e.state);

        emit EggScratched(e.state, _zaiId, msg.sender);
        return (_zaiId);
    }

    function getPriceToClaim(uint256 _tokenId) external view returns (uint256) {
        return _getPriceToClaim(_tokenId);
    }

    function _getPriceToClaim(uint256 _tokenId)
        internal
        view
        returns (uint256)
    {
        uint256 _maturity = _egg[_tokenId].maturityTimestamp;
        if (_maturity > block.timestamp) {
            uint256 nbOfHours = ((_maturity - block.timestamp) / 3600) + 1;
            return nbOfHours * _hourAccelarationPrice;
        } else {
            return 0;
        }
    }

    // UPDATE AUDIT : function won't burn 100% but use the distributeFees (At begining 80% burn + 20% for rewards pool)
    function payForClaimZai(uint256 _tokenId, string memory _zaiName)
        external
        returns (uint256)
    {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");
        require(msg.sender == ownerOf(_tokenId), "Not yours");
        uint256 _toBurn = _getPriceToClaim(_tokenId);

        // UPDATE AUDIT : user can use his pending reward
        if (_toBurn != 0) {
            IPayments IPay = IPayments(
                gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
            );
            require(IPay.payWithRewardOrWallet(msg.sender, _toBurn));
            require(IPay.distributeFees(_toBurn));
        }

        Egg memory e = _egg[_tokenId];

        if (e.isCoverBy != 0) {
            _chickenBusy[e.isCoverBy] = false;
        }

        delete _egg[_tokenId];

        _burn(_tokenId);
        uint256 _zaiId = _generateRandomZai(_zaiName, msg.sender, e.state);
        emit EggScratched(e.state, _zaiId, msg.sender);
        return (_zaiId);
    }

    function _generateRandomZai(
        string memory _name,
        address _user,
        uint256 _state
    ) internal returns (uint256) {
        uint256 zaiId = IZaiNFT(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_NFT)
        ).mintZai(_user, _name, _state);
        return zaiId;
    }

    function coverEggWithChicken(uint256 _tokenId, uint256 _chickenId)
        external
    {
        require(
            IERC721(gameAddresses.getAddressOf(AddressesInit.Addresses.CHICKEN))
                .ownerOf(_chickenId) == msg.sender,
            "not your chicken"
        );
        require(ownerOf(_tokenId) == msg.sender, "not your egg");
        require(!_chickenBusy[_chickenId], "Chicken is busy");
        Egg storage e = _egg[_tokenId];

        uint256 _originMaturity = e.maturityTimestamp;
        uint256 _newMaturity = block.timestamp + 1 days;

        require(
            _originMaturity > _newMaturity,
            "Doesn't need to cover this egg"
        );

        _chickenBusy[_chickenId] = true;
        e.isCoverBy = _chickenId;
        e.maturityTimestamp = uint32(_newMaturity);

        emit MaturitiesUpdated(_tokenId, _originMaturity, _newMaturity);
    }
}
