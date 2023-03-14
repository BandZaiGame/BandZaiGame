// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// contract who manage training center NFT
// owner of NFT can set training slots with coach or not , select duration and price of slots
// coach will get a part of the training price
// Zai who train in a slot will raise his xp (1sec training give 1xp point)
// when zai is training with coach, he will win more xp ((level Coach - level Zai +1) * seconds of training)

contract TrainingManagement is Ownable {
    IAddresses public gameAddresses;
    IFighting public IFight;
    ITraining public ITrainNFT;
    IZaiNFT public IZai;
    IZaiMeta public IZMeta;
    IDelegate public IDel;
    IPayments public IPay;
    IOpenAndClose public IOpen;

    uint256 public addSpotPrice = 200000 * 1E18;

    uint256 public minimumTrainingPrice = 100 * 1E18;
    uint256 constant MAX_DURATION_TRAINING = 21600; // 6 h

    uint256 public levelDiffCap = 10;

    mapping(uint256 => uint256) _lastTrainTimestamp;

    mapping(uint256 => TrainingStruct.Stats) public zaiStats;
    mapping(address => TrainingStruct.Stats) public userStats;

    mapping(uint256 => TrainingStruct.TrainingDetails) public trainingDetails;

    event TrainingPurchase(
        address indexed trainingOwner,
        address indexed buyer,
        uint256 purchasedPrice,
        uint256 trainingId,
        uint256 spotId,
        uint256 zaiId
    );
    event CoachPaid(
        address indexed coachOwner,
        address buyer,
        uint256 purchasedPrice,
        uint256 trainingId,
        uint256 spotId,
        uint256 coachId
    );
    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address fighting,
        address trainingNFT,
        address zai,
        address zaiMeta,
        address delegate,
        address payments,
        address openAndClose
    );
    event MinimumTrainingPriceUpdated(uint256 previousPrice, uint256 nextPrice);
    event SpotPriceUpdated(uint256 previousPrice, uint256 nextPrice);
    event LevelCapUpdated(uint256 oldMetric, uint256 NewMetric);

    constructor(ITraining _trainNFT) {
        ITrainNFT = _trainNFT;
        uint256 _preMintTrain = ITrainNFT.getPreMintNumber();
        for (uint256 i = 1; i <= _preMintTrain; ) {
            trainingDetails[i].numberOfSpots = ITrainNFT.numberOfTrainingSpots(
                i
            );
            unchecked {
                ++i;
            }
        }
    }

    modifier onlyCenterOwner(uint256 _trainingId) {
        require(
            ITrainNFT.ownerOf(_trainingId) == msg.sender,
            "Not your center"
        );
        _;
    }

    modifier canUseZai(uint256 _zaiId) {
        require(
            IDel.canUseZai(_zaiId, msg.sender),
            "Not your zai nor delegated"
        );
        _;
    }

    modifier zaiReady(uint256 _zaiId) {
        require(IZMeta.isFree(_zaiId), "Zai not free");
        require(
            block.timestamp >= _lastTrainTimestamp[_zaiId] + 1 days,
            "zai need to rest: only 1 training by day"
        );
        _;
    }

    function setGameAddresses(address _address) external onlyOwner {
        require(gameAddresses == IAddresses(address(0x0)), "Already setted");
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function updateInterfaces() external {
        IFight = IFighting(
            gameAddresses.getAddressOf(AddressesInit.Addresses.FIGHT)
        );
        ITrainNFT = ITraining(
            gameAddresses.getAddressOf(AddressesInit.Addresses.TRAINING_NFT)
        );
        IZai = IZaiNFT(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_NFT)
        );
        IZMeta = IZaiMeta(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_META)
        );
        IDel = IDelegate(
            gameAddresses.getAddressOf(AddressesInit.Addresses.DELEGATE)
        );
        IPay = IPayments(
            gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
        );
        IOpen = IOpenAndClose(
            gameAddresses.getAddressOf(AddressesInit.Addresses.OPEN_AND_CLOSE)
        );
        emit InterfacesUpdated(
            address(IFight),
            address(ITrainNFT),
            address(IZai),
            address(IZMeta),
            address(IDel),
            address(IPay),
            address(IOpen)
        );
    }

    // UPDATE AUDIT : used when openAndClose create a new center for init number of spot
    function initSpotsNumber(uint256 _tokenId) external returns (bool) {
        require(msg.sender == address(ITrainNFT), "Only");
        trainingDetails[_tokenId].numberOfSpots = 3;
        return true;
    }

    // UPDATE AUDIT : levelDiff is capped
    function setLevelDiffCap(uint256 _levelDiffCap) external onlyOwner {
        uint256 oldMetric = levelDiffCap;
        levelDiffCap = _levelDiffCap;
        emit LevelCapUpdated(oldMetric, _levelDiffCap);
    }

    function setSpotPrice(uint256 _price) external onlyOwner {
        uint256 _previousPrice = addSpotPrice;
        addSpotPrice = _price;
        emit SpotPriceUpdated(_previousPrice, _price);
    }

    function setminimumTrainingPrice(uint256 _price) external onlyOwner {
        uint256 _previousPrice = minimumTrainingPrice;
        minimumTrainingPrice = _price;
        emit MinimumTrainingPriceUpdated(_previousPrice, _price);
    }

    // UPDATE AUDIT : for front end
    function getTrainingCenterDetails(uint256 _tokenId)
        external
        view
        returns (TrainingStruct.TrainingDetails memory)
    {
        return trainingDetails[_tokenId];
    }

    function getZaiLastTrainBegining(uint256 _zaiId)
        external
        view
        returns (uint256)
    {
        return _lastTrainTimestamp[_zaiId];
    }

    function upgradeTC(uint256 _quantity, uint256 _trainingId)
        external
        onlyCenterOwner(_trainingId)
        returns (bool)
    {
        uint256 _totalPrice = _quantity * addSpotPrice;
        require(IPay.payWithRewardOrWallet(msg.sender, _totalPrice));
        IPay.distributeFees(_totalPrice);

        require(ITrainNFT.addTrainingSpots(_trainingId, _quantity));
        trainingDetails[_trainingId].numberOfSpots += _quantity;
        return true;
    }

    // UPDATE AUDIT : training with coach is capped to 3h
    function setTrainingSpot(
        uint256 _spotId,
        uint256 _trainingId,
        uint256 _duration,
        uint256 _price,
        bool _coachNeeded,
        uint256 _minCoachLevel,
        uint256 _coachPercentPayment
    ) external onlyCenterOwner(_trainingId) {
        require(IOpen.canTrain(_trainingId), "!Ready");
        require(
            _minCoachLevel <= 50,
            "Be serious ! a coach can't be more than level 50 "
        );

        require(
            trainingDetails[_trainingId].numberOfSpots > _spotId,
            "Spot doesn't exist!"
        );

        // UPDATE AUDIT : training with coach is capped to 3h
        //              && minimum price with coach * 2
        if (_coachNeeded) {
            require(
                _duration <= MAX_DURATION_TRAINING / 2,
                "Training with coach can't exceed 3h"
            );
            require(_price >= minimumTrainingPrice * 2, "Price too low");
            require(_coachPercentPayment <= 90, "maximum 90% for the coach");
            require(_coachPercentPayment >= 10, "minimum 10% for the coach");
        } else {
            require(
                _duration <= MAX_DURATION_TRAINING,
                "Training can't exceed 6h"
            );
            require(_price >= minimumTrainingPrice, "Price too low");
        }

        TrainingStruct.TrainingInstance storage t = trainingDetails[_trainingId]
            .trainingSpots[_spotId];

        // UPDATE AUDIT : owner of center can change setup of training spot at any time
        // this way kick a coach or stop hiring isn't needed
        // if spot fininished or didn't start, we clean the spot for coaching and training
        if (block.timestamp >= t.endAt || t.endAt == 0) {
            _cleanSlot(_trainingId, _spotId);
        }

        t.duration = _duration;
        t.price = _price;

        if (_coachNeeded) {
            t.coach.minLevelReq = _minCoachLevel;
            t.coach.percentPayment = _coachPercentPayment;
            t.coach.coachRequired = true;
        } else {
            t.spotOpened = true;
        }
    }

    function registerCoaching(
        uint256 _zaiId,
        uint256 _spotId,
        uint256 _trainingId
    ) external canUseZai(_zaiId) zaiReady(_zaiId) {
        TrainingStruct.TrainingInstance storage t = trainingDetails[_trainingId]
            .trainingSpots[_spotId];
        require(t.coach.coachRequired, "Spot doesn't need a coach !");
        require(
            t.coach.coachId == 0 || (block.timestamp > t.endAt && t.endAt != 0),
            "Got coach or training not finished"
        );

        if (block.timestamp > t.endAt && t.endAt != 0) {
            _cleanSlot(_trainingId, _spotId);
        }

        ZaiStruct.Zai memory z = IZMeta.getZai(_zaiId);

        require(z.level >= t.coach.minLevelReq, "!Level");
        require(z.activity.statusId == 0, "Zai!=Free");

        t.coach.coachId = _zaiId;
        t.spotOpened = true;
        t.coach.currentCoachLevel = z.level;
        IZMeta.updateStatus(_zaiId, 2, _trainingId, _spotId);
    }

    function beginTraining(
        uint256 _spotId,
        uint256 _trainingId,
        uint256 _zaiId,
        uint256 _maxPrice
    ) external canUseZai(_zaiId) zaiReady(_zaiId) {
        _lastTrainTimestamp[_zaiId] = block.timestamp;
        TrainingStruct.TrainingInstance storage t = trainingDetails[_trainingId]
            .trainingSpots[_spotId];

        require(t.spotOpened, "Spot not opened");
        require(block.timestamp >= t.endAt, "Previous training not finished");

        ++zaiStats[_zaiId].trainingNumber;
        ++userStats[msg.sender].trainingNumber;

        address ownerOfTC = ITrainNFT.ownerOf(_trainingId);
        uint256 ownerPayment = t.price;
        uint256 coachPayment;
        address ownerOfCoach;

        if (t.coach.coachId != 0) {
            require(t.zaiId == 0, "coach need to rest");
            _lastTrainTimestamp[t.coach.coachId] = block.timestamp;

            coachPayment = (ownerPayment * t.coach.percentPayment) / 100;
            ownerPayment -= coachPayment;
            ownerOfCoach = IZai.ownerOf(t.coach.coachId);

            ++zaiStats[t.coach.coachId].coachingNumber;
            ++userStats[ownerOfCoach].coachingNumber;
        }
        if (t.zaiId != 0) {
            _updateZai(t.zaiId, t.duration, t.coach.coachId);
            uint256 _tempZaiId = t.zaiId;
            t.zaiId = 0;
            IZMeta.updateStatus(_tempZaiId, 0, 0, 0);
        }

        require(
            _maxPrice >= ownerPayment + coachPayment,
            "Price has been changed"
        );

        trainingDetails[_trainingId].revenues += t.price;
        t.endAt = block.timestamp + t.duration;
        t.zaiId = _zaiId;

        IZMeta.updateStatus(_zaiId, 1, _trainingId, _spotId);

        require(
            IPay.payWithRewardOrWallet(msg.sender, ownerPayment + coachPayment)
        );

        IPay.payOwner(ownerOfTC, ownerPayment);

        if (coachPayment != 0) {
            IPay.payOwner(ownerOfCoach, coachPayment);
            emit CoachPaid(
                ownerOfCoach,
                msg.sender,
                coachPayment,
                _trainingId,
                _spotId,
                t.coach.coachId
            );
        }
        emit TrainingPurchase(
            ownerOfTC,
            msg.sender,
            ownerPayment + coachPayment,
            _trainingId,
            _spotId,
            _zaiId
        );
    }

    function cleanSpot(uint256 _trainingId, uint256 _spotId)
        external
        onlyCenterOwner(_trainingId)
    {
        _cleanSlot(_trainingId, _spotId);
    }

    function quiteCoaching(
        uint256 _zaiId,
        uint256 _spotId,
        uint256 _trainingId
    ) external canUseZai(_zaiId) {
        TrainingStruct.TrainingInstance storage t = trainingDetails[_trainingId]
            .trainingSpots[_spotId];
        require(
            _zaiId == t.coach.coachId,
            "Not your Zai who's coaching in this training slot"
        );

        _cleanSlot(_trainingId, _spotId);
    }

    function finishTraining(
        uint256 _spotId,
        uint256 _trainingId,
        uint256 _zaiId
    ) external canUseZai(_zaiId) {
        TrainingStruct.TrainingInstance memory t = trainingDetails[_trainingId]
            .trainingSpots[_spotId];
        require(_zaiId == t.zaiId, "Not your Zai in this training slot");

        _cleanSlot(_trainingId, _spotId);
    }

    function cleanSlotsBeforeClosing(uint256 _trainingId)
        external
        returns (bool)
    {
        require(msg.sender == address(IOpen), "Not authorized to clean spot");
        uint256 numberOfTrainingSpots = trainingDetails[_trainingId]
            .numberOfSpots;
        if (numberOfTrainingSpots == 0) {
            return true;
        } else {
            for (uint256 i = 1; i <= numberOfTrainingSpots; ) {
                _cleanSlot(_trainingId, i);
                unchecked {
                    ++i;
                }
            }
            return true;
        }
    }

    function _cleanSlot(uint256 _trainingId, uint256 _spotId) internal {
        TrainingStruct.TrainingInstance storage t = trainingDetails[_trainingId]
            .trainingSpots[_spotId];
        require(block.timestamp >= t.endAt, "training is not over");
        t.endAt = 0;
        if (t.zaiId != 0) {
            uint256 _zaiId = t.zaiId;
            _updateZai(t.zaiId, t.duration, t.coach.coachId);
            t.zaiId = 0;
            IZMeta.updateStatus(_zaiId, 0, 0, 0);
        }
        if (t.coach.coachId != 0) {
            uint256 _coachId = t.coach.coachId;
            t.coach.coachId = 0;
            t.coach.currentCoachLevel = 0;
            t.spotOpened = false;
            IZMeta.updateStatus(_coachId, 0, 0, 0);
        }
    }

    function _updateZai(
        uint256 _zaiId,
        uint256 _duration,
        uint256 _coachId
    ) private {
        ZaiStruct.Zai memory z = IZMeta.getZai(_zaiId);
        // UPDATE AUDIT : 1 sec training give 0.5pts xp
        _duration /= 2;

        if (_coachId != 0) {
            ZaiStruct.Zai memory c = IZMeta.getZai(_coachId);
            if (c.level > z.level) {
                uint256 levelDiff = (c.level - z.level + 1);
                // UPDATE AUDIT : levelDiff is capped
                _duration =
                    _duration *
                    (levelDiff > levelDiffCap ? levelDiffCap : levelDiff); // max multiplier cap
            }
        }

        uint256 levelTens = z.level - (z.level % 10);
        uint256 multiplierXp = 1;
        if (levelTens != 0) {
            multiplierXp = (levelTens / 10) + 1; // if level 10+ duration is multiply by 2 // if level 20+ duration is multiply by 3...
        }

        IZMeta.updateXp(_zaiId, _duration * multiplierXp);
    }
}
