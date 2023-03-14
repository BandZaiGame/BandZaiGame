// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Interfaces.sol";

// Potion NFT are NFT used in fight to give advantage to Zai
// there is 9 kinds of potion :
// - elements potion (fire, water, stone,metal, air) and "empty potion"(type 99)
// - xp potion used to win more xp in fight
// - rest potion used to restore stamina of a Zai (restore 5 fights)
// - mana potion used for alchemy (mixing potion)
// UPDATE AUDIT : add totalSupply() method

contract PotionNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 _totalSupply;

    IAddresses public gameAddresses;
    IPayments public IPay;
    ILaboratory public laboNFT;
    address public laboManagement;

    mapping(uint256 => PotionStruct.Potion) private _potions;
    uint256 public restPotionsPrice = 50 * 1E18;
    uint256 public xpPotionsPrice = 10 * 1E18;

    mapping(uint256 => uint256) _stateIndex;

    event XpPotionPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event RestPotionPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address laboManagement,
        address payments,
        address laboNFT
    );
    event PotionEmptyed(uint256 tokenId);
    event PotionBought(uint256 tokenId, uint256 potionType);

    constructor() ERC721("Potion_BandZai_NFT", "POTION") {}

    modifier onlyAuth() {
        require(gameAddresses.isAuthToManagedNFTs(msg.sender), "Not allowed");
        _;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
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
        laboManagement = gameAddresses.getAddressOf(
            AddressesInit.Addresses.LABO_MANAGEMENT
        );
        IPay = IPayments(
            gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
        );
        laboNFT = ILaboratory(
            gameAddresses.getAddressOf(AddressesInit.Addresses.LABO_NFT)
        );
        emit InterfacesUpdated(laboManagement, address(IPay), address(laboNFT));
    }

    function setXpPotionsPrice(uint256 _price) external onlyOwner {
        require(_price != 0, "Price can't be 0");
        uint256 _oldPrice = xpPotionsPrice;
        xpPotionsPrice = _price;
        emit XpPotionPriceUpdated(_oldPrice, _price);
    }

    function setRestPotionsPrice(uint256 _price) external onlyOwner {
        require(_price != 0, "Price can't be 0");
        uint256 _oldPrice = restPotionsPrice;
        restPotionsPrice = _price;
        emit RestPotionPriceUpdated(_oldPrice, _price);
    }

    // UPDATE AUDIT : re factoring offerPotion and mintPotionForSale with _mintPotion
    //_safeMint() is at end of function
    function offerPotion(
        uint256 _type,
        uint256 _power,
        address _to
    ) external onlyAuth returns (uint256) {
        return _mintPotion(0, 0, uint8(_type), uint8(_power), _to);
    }

    // UPDATE AUDIT : multiple mint is here now avoiding multiple external call
    function mintPotionForSale(
        uint256 _laboId,
        uint256 _price,
        uint256 _type,
        uint256 _power,
        uint256 _quantity
    ) external returns (uint256[] memory) {
        require(msg.sender == laboManagement, "only labo management accepted");
        uint256[] memory _potionIds = new uint256[](_quantity);
        for (uint256 i = 0; i < _quantity; ) {
            _potionIds[i] = _mintPotion(
                _laboId,
                _price,
                uint8(_type),
                uint8(_power),
                laboManagement
            );
            unchecked {
                ++i;
            }
        }
        return _potionIds;
    }

    function _mintPotion(
        uint256 _laboId,
        uint256 _price,
        uint256 _type,
        uint256 _power,
        address _to
    ) internal returns (uint256 newPotionId) {
        require(
            (_type <= 4 && _power != 0) || (_type == 8 && _power != 0),
            "Not valid potion"
        );

        newPotionId = _getNewId();
        _setPotion(newPotionId, uint8(_type), uint8(_power), _price, _laboId);

        _safeMint(_to, newPotionId);
    }

    // UPDATE AUDIT : re factoring incrementation + newTokenId
    function _getNewId() internal returns (uint256) {
        _tokenIds.increment();
        _totalSupply++;
        return _tokenIds.current();
    }

    // UPDATE AUDIT : re factoring
    function _setPotion(
        uint256 _potionId,
        uint8 _type,
        uint8 _power,
        uint256 _price,
        uint256 _laboId
    ) internal {
        PotionStruct.Potion storage i = _potions[_potionId];
        i.potionType = _type;
        if (_type == 0) {
            i.powers.water = _power;
        } else if (_type == 1) {
            i.powers.fire = _power;
        } else if (_type == 2) {
            i.powers.metal = _power;
        } else if (_type == 3) {
            i.powers.air = _power;
        } else if (_type == 4) {
            i.powers.stone = _power;
        } else if (_type == 8) {
            i.powers.mana = _power * 100;
        }
        i.potionId = _potionId;

        if (_price != 0) {
            i.listingPrice = _price;
            i.seller = laboNFT.ownerOf(_laboId);
            i.fromLab = _laboId;
        }
    }

    function changePotionPrice(
        uint256 _tokenId,
        uint256 _laboId,
        uint256 _price
    ) external onlyAuth returns (bool) {
        PotionStruct.Potion storage i = _potions[_tokenId];
        require(_laboId == i.fromLab, "Not the good lab");
        i.listingPrice = _price;
        return true;
    }

    function updatePotionSaleTimestamp(uint256 _tokenId)
        external
        onlyAuth
        returns (bool)
    {
        _potions[_tokenId].saleTimestamp = block.timestamp;
        return true;
    }

    function mintMultiplePotion(uint256[7] memory _powers, address _owner)
        external
        onlyAuth
        returns (uint256 newPotionId)
    {
        newPotionId = _getNewId();

        PotionStruct.Potion storage i = _potions[newPotionId];
        i.potionType = 7;
        i.powers.water = uint8(_powers[0]);
        i.powers.fire = uint8(_powers[1]);
        i.powers.metal = uint8(_powers[2]);
        i.powers.air = uint8(_powers[3]);
        i.powers.stone = uint8(_powers[4]);
        i.powers.xp = uint8(_powers[5]);
        i.powers.mana = uint8(_powers[6]);

        i.potionId = newPotionId;

        _safeMint(_owner, newPotionId);
    }

    // UPDATE AUDIT : delete the 5 potions limit
    function buyXpPotion(uint256 _quantity) external {
        // one potion offer when 5 bought
        uint256 _offered = _quantity / 5;
        uint256 _price = (_quantity - _offered) * xpPotionsPrice;

        if (_quantity % 5 == 4) {
            _quantity += 1;
        }

        require(IPay.payWithRewardOrWallet(msg.sender, _price));
        IPay.distributeFees(_price);
        address _to = msg.sender;

        for (uint256 i; i < _quantity; ) {
            uint256 _newPotionId = _getNewId();
            PotionStruct.Potion storage _potion = _potions[_newPotionId];
            _potion.potionType = 6;
            _potion.powers.xp = 2;
            emit PotionBought(_newPotionId, 6);
            _safeMint(_to, _newPotionId);

            unchecked {
                ++i;
            }
        }
    }

    // UPDATE AUDIT : delete the 5 potions limit
    function buyRestPotion(uint256 _quantity) external {
        // one potion offer when 5 bought
        uint256 _offered = _quantity / 5;
        uint256 _price = (_quantity - _offered) * xpPotionsPrice;

        if (_quantity % 5 == 4) {
            _quantity += 1;
        }

        require(IPay.payWithRewardOrWallet(msg.sender, _price));
        IPay.distributeFees(_price);
        address _to = msg.sender;

        for (uint256 i; i < _quantity; ) {
            uint256 _newPotionId = _getNewId();
            PotionStruct.Potion storage _potion = _potions[_newPotionId];
            _potion.potionType = 5;
            _potion.powers.rest = 5;
            emit PotionBought(_newPotionId, 5);

            _safeMint(_to, _newPotionId);

            unchecked {
                ++i;
            }
        }
    }

    function getFullPotion(uint256 _tokenId)
        external
        view
        returns (PotionStruct.Potion memory)
    {
        return _potions[_tokenId];
    }

    // UPDATE AUDIT : use it in fight for GAS fees optimization
    function getPotionPowers(uint256 _tokenId)
        external
        view
        returns (PotionStruct.Powers memory)
    {
        return _potions[_tokenId].powers;
    }

    function emptyingPotion(uint256 _tokenId) external onlyAuth returns (bool) {
        _potions[_tokenId] = PotionStruct.Potion(
            address(0x0),
            0,
            0,
            0,
            0,
            99,
            PotionStruct.Powers(0, 0, 0, 0, 0, 0, 0, 0)
        );
        emit PotionEmptyed(_tokenId);
        return true;
    }

    function burnPotion(uint256 _tokenId) external onlyAuth returns (bool) {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        _totalSupply--;
        _burn(_tokenId);
        return true;
    }
}
