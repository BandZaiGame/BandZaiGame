// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Interfaces.sol";

// Labo management is where labo owner will create potion with credit
// Credit come from workers in labo and time passed in
// workers are Zais who want to be sorceler , when a Zai work in spot in a Labo, he will gain mana
contract LaboManagement is ERC721Holder, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    IAddresses public gameAddresses;
    IPotions public Potions;
    ILaboratory public ILabNFT;
    IPayments public IPay;
    IZaiNFT public IZai;
    IZaiMeta public ZaiMeta;
    IOpenAndClose public IOpen;
    IDelegate public IDel;
    address public claimNftAddress;

    uint256 public workingSpotPrice = 200_000 * 1E18;

    // a Labo can't have infinite credit, it is capped
    // owner have to come and create potion to use credit of labo
    uint256 public maxCredit = 2_000_000;

    uint256 public pointCreditCost = 10_000;

    // stored for futur rewards
    mapping(uint256 => uint256) public zaiNumberOfWork;
    mapping(address => uint256) public userNumberOfWork;

    mapping(uint256 => LaboStruct.LabDetails) public labDetails;

    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address potions,
        address payments,
        address zaiNFT,
        address zaiMeta,
        address openAndClose,
        address delegate,
        address claimNFT
    );
    event PotionSold(
        address indexed labOwner,
        uint256 indexed laboId,
        address indexed buyer,
        uint256 price,
        uint256 potionId
    );
    event PotionCreatedForSale(
        address indexed labOwner,
        uint256 indexed laboId,
        uint256 price,
        uint256 potionId,
        uint256 potionType,
        uint256 potionPower
    );
    event PotionPriceChanged(uint256 potionId, uint256 price);
    event PotionOffered(
        address indexed labOwner,
        uint256 indexed laboId,
        address indexed offeredTo,
        uint256 potionId,
        uint256 potionType,
        uint256 potionPower
    );
    event MetricsChanged(
        string indexed metricType,
        uint256 oldMetric,
        uint256 newMetric
    );

    constructor(ILaboratory _laboNFT) {
        ILabNFT = _laboNFT;
        uint256 _preMintLabs = ILabNFT.getPreMintNumber();
        for (uint256 i = 1; i <= _preMintLabs; ) {
            labDetails[i].numberOfSpots = ILabNFT.numberOfWorkingSpots(i);
            unchecked {
                ++i;
            }
        }
    }

    modifier onlyLaboOwner(uint256 _laboId) {
        require(ILabNFT.ownerOf(_laboId) == msg.sender, "Not your Lab");
        _;
    }

    modifier canUseZai(uint256 _zaiId) {
        require(
            IDel.canUseZai(_zaiId, msg.sender),
            "Not your zai nor delegated"
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

    function updateInterfaces() external {
        Potions = IPotions(
            gameAddresses.getAddressOf(AddressesInit.Addresses.POTIONS_NFT)
        );
        IPay = IPayments(
            gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
        );
        IZai = IZaiNFT(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_NFT)
        );
        ZaiMeta = IZaiMeta(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_META)
        );
        IOpen = IOpenAndClose(
            gameAddresses.getAddressOf(AddressesInit.Addresses.OPEN_AND_CLOSE)
        );
        IDel = IDelegate(
            gameAddresses.getAddressOf(AddressesInit.Addresses.DELEGATE)
        );
        claimNftAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.CLAIM_NFTS
        );
        emit InterfacesUpdated(
            address(Potions),
            address(IPay),
            address(IZai),
            address(ZaiMeta),
            address(IOpen),
            address(IDel),
            claimNftAddress
        );
    }

    // UPDATE AUDIT : used when openAndClose create a new center for init number of spot
    function initSpotsNumber(uint256 _tokenId) external returns (bool) {
        require(msg.sender == address(ILabNFT), "Only lab");
        labDetails[_tokenId].numberOfSpots = 3;
        return true;
    }

    function setPointCreditCost(uint256 _cost) external onlyOwner {
        uint256 oldCost = pointCreditCost;
        pointCreditCost = _cost;
        emit MetricsChanged("POINT_CREDIT_COST", oldCost, _cost);
    }

    function setMaxCredit(uint256 _credit) external onlyOwner {
        require(_credit >= 1000000 && _credit <= 10000000, "Not a good value");
        uint256 _oldMetric = maxCredit;
        maxCredit = _credit;
        emit MetricsChanged(
            "MAX_CREDIT_CAP_FOR_LABORATORY",
            _oldMetric,
            _credit
        );
    }

    function setWorkingSpotPrice(uint256 _price) external onlyOwner {
        uint256 _oldMetric = workingSpotPrice;
        workingSpotPrice = _price;
        emit MetricsChanged(
            "WORKING_SPOT_PRICE_FOR_LABORATORY",
            _oldMetric,
            _price
        );
    }

    // UPDATE AUDIT : for front end
    function getLabDetails(uint256 _tokenId)
        external
        view
        returns (LaboStruct.LabDetails memory)
    {
        LaboStruct.LabDetails memory lab = labDetails[_tokenId];
        if (lab.potionsCredits > maxCredit) {
            lab.potionsCredits = maxCredit;
        }
        return lab;
    }

    // UPDATE AUDIT : can add more than 1 spot
    function addWorkingSpotToLab(uint256 _laboId, uint256 _quantity)
        external
        onlyLaboOwner(_laboId)
        returns (bool)
    {
        uint256 _totalPrice = workingSpotPrice * _quantity;

        require(IPay.payWithRewardOrWallet(msg.sender, _totalPrice));
        IPay.distributeFees(_totalPrice);

        require(ILabNFT.updateNumberOfWorkingSpots(_laboId, _quantity));
        labDetails[_laboId].numberOfSpots += _quantity;
        return true;
    }

    function workInASpot(
        uint256 _zaiId,
        uint256 _laboId,
        uint256 _spotId
    ) external canUseZai(_zaiId) {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");

        require(ILabNFT.ownerOf(_laboId) != claimNftAddress, "Lab not active");
        require(ZaiMeta.isFree(_zaiId), "Not Free");
        require(
            ILabNFT.numberOfWorkingSpots(_laboId) > _spotId,
            "spot doesn't exist"
        );
        LaboStruct.WorkInstance storage w = labDetails[_laboId].workingSpot[
            _spotId
        ];
        require(
            w.zaiId == 0 || block.timestamp > w.beginingAt + 1 days,
            "Spot not free"
        );

        _updateCredits(_laboId);

        if (w.zaiId != 0) {
            require(
                _updateZai(
                    w.zaiId,
                    _getManaWon(block.timestamp, w.beginingAt),
                    true
                )
            );
        } else {
            ++labDetails[_laboId].employees;
        }
        w.zaiId = _zaiId;
        w.beginingAt = block.timestamp;
        ZaiMeta.updateStatus(_zaiId, 3, _laboId, _spotId);
    }

    function stopWorking(
        uint256 _zaiId,
        uint256 _laboId,
        uint256 _spotId
    ) external canUseZai(_zaiId) {
        // UPDATE AUDIT : delete checking spot existance => we only need to check zai working on spot
        LaboStruct.WorkInstance storage w = labDetails[_laboId].workingSpot[
            _spotId
        ];
        require(w.zaiId == _zaiId, "Your zai doesn't work on this spot");
        require(
            _updateZai(
                w.zaiId,
                _getManaWon(block.timestamp, w.beginingAt),
                (block.timestamp - w.beginingAt > 1 days)
            )
        );
        w.beginingAt = 0;
        w.zaiId = 0;
        --labDetails[_laboId].employees;
        _updateCredits(_laboId);
    }

    function _getManaWon(uint256 _finished, uint256 _start)
        internal
        pure
        returns (uint256 mana)
    {
        uint256 _duration = _finished - _start;
        if (_duration <= 21600) {
            // less than 6 h
            mana = 0;
        } else if (_duration <= 43200) {
            // less than 12h
            mana = 500;
        } else if (_duration <= 86400) {
            // less than 24h
            mana = 1000;
        } else if (_duration <= 129600) {
            // less than 36h
            mana = 2000;
        } else {
            mana = 3000;
        }
    }

    // manaMax is the maximum a Zai can store in mana
    // to increase manaMax, a Zai must finish at least 24h of work in a spot
    // a Zai can't have more than 10k of manamax
    function _updateZai(
        uint256 _zaiId,
        uint256 _mana,
        bool _manaMaxUpgrade
    ) internal returns (bool) {
        ZaiMeta.updateStatus(_zaiId, 0, 0, 0);
        if (_manaMaxUpgrade) {
            ++zaiNumberOfWork[_zaiId];
            ++userNumberOfWork[IZai.ownerOf(_zaiId)];
        }

        return (
            ZaiMeta.updateMana(
                _zaiId,
                _mana,
                0,
                // 2 first work give 1000 manaMax. next give 100
                _manaMaxUpgrade ? zaiNumberOfWork[_zaiId] <= 2 ? 1000 : 100 : 0
            )
        );
    }

    function getCredit(uint256 _laboId) external view returns (uint256) {
        return _getCredit(_laboId);
    }

    function _getCredit(uint256 _laboId)
        internal
        view
        returns (uint256 credits)
    {
        LaboStruct.LabDetails memory lab = labDetails[_laboId];
        uint256 _creditLastUpdate = ILabNFT.getCreditLastUpdate(_laboId);

        if (_creditLastUpdate == 0) {
            credits = 0;
        } else {
            uint256 _timePassed = block.timestamp - _creditLastUpdate;
            if (lab.employees != 0) {
                credits = lab.potionsCredits + (_timePassed * lab.employees);
            } else {
                credits = lab.potionsCredits + (_timePassed / 4);
            }
        }
        if (credits > maxCredit) {
            credits = maxCredit;
        }
    }

    // UPDATE AUDIT : multiple mint is in Potion contract avoiding multiple external call
    function createAndSellPotion(
        uint256 _quantity,
        uint256 _price,
        uint256 _type,
        uint256 _power,
        uint256 _laboId
    ) external onlyLaboOwner(_laboId) returns (bool) {
        require(_quantity != 0 && _power != 0, "Quantity and Power can't be 0");
        require(_type < 5 || _type == 8, "not good potion");
        require(_quantity <= 5, "Only 5 potions max can be created by tx");
        require(IOpen.canLaboSell(_laboId), "You can't");
        LaboStruct.LabDetails storage lab = labDetails[_laboId];
        _updateCredits(_laboId);
        require(
            lab.potionsCredits >= (_quantity * _power * pointCreditCost),
            "Not enough credits"
        );

        lab.potionsCredits -= (_quantity * _power * pointCreditCost);
        uint256[] memory potionIds = Potions.mintPotionForSale(
            _laboId,
            _price,
            _type,
            _power,
            _quantity
        );

        for (uint256 i; i < _quantity; ) {
            emit PotionCreatedForSale(
                msg.sender,
                _laboId,
                _price,
                potionIds[i],
                _type,
                _type == 8 ? _power * 100 : _power
            );
            unchecked {
                ++i;
            }
        }

        return true;
    }

    function changePotionPrice(
        uint256 _potionId,
        uint256 _laboId,
        uint256 _price
    ) external onlyLaboOwner(_laboId) returns (bool) {
        emit PotionPriceChanged(_potionId, _price);
        return Potions.changePotionPrice(_potionId, _laboId, _price);
    }

    // offering potion (to owner or anybody) cost 2 x the pointCredit needs
    function offerPotion(
        uint256 _type,
        uint256 _power,
        uint256 _laboId,
        address _to
    ) external onlyLaboOwner(_laboId) {
        require(_type < 5 || _type == 8, "not good potion");
        require(IOpen.canLaboSell(_laboId), "You can't");
        LaboStruct.LabDetails storage lab = labDetails[_laboId];
        _updateCredits(_laboId);
        require(
            lab.potionsCredits >= (_power * 2 * pointCreditCost),
            "Not enough credits"
        );
        lab.potionsCredits -= (_power * 2 * pointCreditCost);

        uint256 potionId = Potions.offerPotion(_type, _power, _to);

        emit PotionOffered(
            msg.sender,
            _laboId,
            _to,
            potionId,
            _type,
            _type == 8 ? _power * 100 : _power
        );
    }

    function buyPotions(
        uint256[] memory _potionsIds,
        uint256[] memory _maxPrice
    ) external {
        for (uint256 i; i < _potionsIds.length; ) {
            buyPotion(_potionsIds[i], _maxPrice[i]);
            unchecked {
                ++i;
            }
        }
    }

    function buyPotion(uint256 _potionId, uint256 _maxPrice) public {
        require(Potions.ownerOf(_potionId) == address(this), "Not in sale");

        PotionStruct.Potion memory p = Potions.getFullPotion(_potionId);
        require(
            IOpen.canLaboSell(p.fromLab),
            "Labo who mint this potion is closed"
        );

        require(_maxPrice >= p.listingPrice, "Price changed");

        require(IPay.payWithRewardOrWallet(msg.sender, p.listingPrice));
        IPay.payOwner(p.seller, p.listingPrice);

        require(Potions.updatePotionSaleTimestamp(_potionId));

        labDetails[p.fromLab].revenues += p.listingPrice;

        IERC721(address(Potions)).transferFrom(
            address(this),
            msg.sender,
            _potionId
        );

        emit PotionSold(
            p.seller,
            p.fromLab,
            msg.sender,
            p.listingPrice,
            _potionId
        );
    }

    // used to prevent Zai locked in a "work" instance when a labo is in close process
    function cleanSlotsBeforeClosing(uint256 _laboId) external returns (bool) {
        require(msg.sender == address(IOpen), "Not authorized to clean");
        LaboStruct.LabDetails storage lab = labDetails[_laboId];

        if (lab.employees == 0) {
            return true;
        } else {
            uint256 numberOfSpots = ILabNFT.numberOfWorkingSpots(_laboId);
            for (uint256 i = 0; i < numberOfSpots; ) {
                LaboStruct.WorkInstance storage w = lab.workingSpot[i];
                if (w.zaiId != 0) {
                    bool _manaMaxUpgrade = block.timestamp - w.beginingAt >
                        1 days;
                    require(
                        _updateZai(
                            w.zaiId,
                            _getManaWon(block.timestamp, w.beginingAt),
                            _manaMaxUpgrade
                        )
                    );
                    w.beginingAt = 0;
                    w.zaiId = 0;
                    --lab.employees;
                    if (lab.employees == 0) {
                        break;
                    }
                }
                unchecked {
                    ++i;
                }
            }
            return true;
        }
    }

    function _updateCredits(uint256 _laboId) internal {
        uint256 _credit = _getCredit(_laboId);
        require(ILabNFT.updateCreditLastUpdate(_laboId));
        labDetails[_laboId].potionsCredits = _credit;
    }
}
