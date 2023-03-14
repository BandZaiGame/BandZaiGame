// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// Training centers and Laboratories can be minted by staking an amount of LP token (BZAI/USDC)
// There is a construction period before center can be used
// there is a destruction period before owner get back his LP tokens
contract OpenAndCloseCenter is Ownable {
    IERC20 LP;
    IAddresses public gameAddresses;
    INurseryNFT public INurs;
    ITraining public ITrain;
    ITrainingManagement public ITrainMan;
    ILaboratory public ILab;
    ILabManagement public ILabMan;

    uint256 maturityHousesDuration = 3 days;
    uint256 closingHousesDuration = 7 days;

    mapping(uint256 => string) public laboratoryName;
    mapping(uint256 => string) public trainingCenterName;
    mapping(uint256 => string) public nurseryName;

    struct ClosingProcess {
        bool isClosing;
        bool destructed;
        uint256 timestampClosedActed;
    }

    //closingProcesses[1][tokenId] => ; TrainingCenter = 1 ; Laboratory = 2
    mapping(uint256 => mapping(uint256 => ClosingProcess))
        public closingProcesses;

    struct CenterDetails {
        uint256 maturityTime;
        uint256 lockedInCenter; // LP locked in this CENTER instance
    }

    mapping(uint256 => CenterDetails) public trainingDetails;
    mapping(uint256 => CenterDetails) public laboratoryDetails;

    uint256 public trainingCenterPrice = 1000000 * 1E18;
    uint256 public laboratoryPrice = 1000000 * 1E18;

    event MaturityUpdated(uint256 oldDuration, uint256 newDuration);
    event ClosingDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event GameAddressesSetted(address gameAddressUpdated);
    event InterfacesUpdated(
        address nurseryAddress,
        address trainingAddress,
        address trainingManagmentAddress,
        address laboratoryAddress,
        address laboManagementAddress
    );
    event LpAddressSetted(address LpAddressUpdated);
    event TrainingCenterPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event LaboratoryPriceUpdated(uint256 oldPrice, uint256 newPrice);

    //TODO Create event for create && close house

    function setMaturityDuration(uint256 _numbersOfDays) external onlyOwner {
        require(_numbersOfDays < 10, "Too long");
        uint256 _oldDuration = maturityHousesDuration;
        maturityHousesDuration = _numbersOfDays * 1 days;
        emit MaturityUpdated(_oldDuration, maturityHousesDuration);
    }

    function setClosingDuration(uint256 _numbersOfDays) external onlyOwner {
        require(_numbersOfDays < 10, "Too long");
        uint256 _oldDuration = closingHousesDuration;
        closingHousesDuration = _numbersOfDays * 1 days;
        emit ClosingDurationUpdated(_oldDuration, closingHousesDuration);
    }

    function setGameAddresses(address _address) public onlyOwner {
        require(
            address(gameAddresses) == address(0x0),
            "game addresses already setted"
        );
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function updateInterfaces() external {
        INurs = INurseryNFT(
            gameAddresses.getAddressOf(AddressesInit.Addresses.NURSERY_NFT)
        );
        ITrain = ITraining(
            gameAddresses.getAddressOf(AddressesInit.Addresses.TRAINING_NFT)
        );
        ITrainMan = ITrainingManagement(
            gameAddresses.getAddressOf(
                AddressesInit.Addresses.TRAINING_MANAGEMENT
            )
        );
        ILab = ILaboratory(
            gameAddresses.getAddressOf(AddressesInit.Addresses.LABO_NFT)
        );
        ILabMan = ILabManagement(
            gameAddresses.getAddressOf(AddressesInit.Addresses.LABO_MANAGEMENT)
        );
        emit InterfacesUpdated(
            address(INurs),
            address(ITrain),
            address(ITrainMan),
            address(ILab),
            address(ILabMan)
        );
    }

    function setLpToken(address _Lp) external onlyOwner {
        require(LP == IERC20(address(0)), "Unauthorized to change address");
        LP = IERC20(_Lp);
        emit LpAddressSetted(_Lp);
    }

    function setTrainingCenterPrice(uint256 _price) external onlyOwner {
        uint256 _oldPrice = trainingCenterPrice;
        trainingCenterPrice = _price;
        emit TrainingCenterPriceUpdated(_oldPrice, _price);
    }

    function setLaboratoryPrice(uint256 _price) external onlyOwner {
        uint256 _oldPrice = laboratoryPrice;
        laboratoryPrice = _price;
        emit LaboratoryPriceUpdated(_oldPrice, _price);
    }

    function getLaboratoryName(uint256 _tokenId)
        external
        view
        returns (string memory)
    {
        return laboratoryName[_tokenId];
    }

    function getNurseryName(uint256 _tokenId)
        external
        view
        returns (string memory)
    {
        return nurseryName[_tokenId];
    }

    function changeNurseryName(string memory _name, uint256 _tokenId) external {
        require(
            INurs.ownerOf(_tokenId) == msg.sender || msg.sender == owner(),
            "Not authorized to change name"
        );

        nurseryName[_tokenId] = _name;
    }

    function getTrainingCenterName(uint256 _tokenId)
        external
        view
        returns (string memory)
    {
        return trainingCenterName[_tokenId];
    }

    function createTrainingCenter(string memory _name)
        external
        returns (uint256)
    {
        require(
            LP.transferFrom(msg.sender, address(this), trainingCenterPrice)
        );
        uint256 trainingId = ITrain.mintTrainingCenter(msg.sender);

        trainingDetails[trainingId] = CenterDetails(
            block.timestamp + maturityHousesDuration,
            trainingCenterPrice
        );

        trainingCenterName[trainingId] = _name;
        return trainingId;
    }

    function changeTrainingCenterName(string memory _name, uint256 _tokenId)
        external
    {
        require(
            ITrain.ownerOf(_tokenId) == msg.sender || msg.sender == owner(),
            "Not authorized to change name"
        );

        trainingCenterName[_tokenId] = _name;
    }

    function createLaboratory(string memory _name) external returns (uint256) {
        require(LP.transferFrom(msg.sender, address(this), laboratoryPrice));
        uint256 laboId = ILab.mintLaboratory(msg.sender);
        laboratoryDetails[laboId] = CenterDetails(
            block.timestamp + maturityHousesDuration,
            laboratoryPrice
        );

        laboratoryName[laboId] = _name;
        return laboId;
    }

    function changeLaboratoryName(string memory _name, uint256 _tokenId)
        external
    {
        require(
            ILab.ownerOf(_tokenId) == msg.sender || msg.sender == owner(),
            "Not authorized to change name"
        );

        laboratoryName[_tokenId] = _name;
    }

    function getTrainingCenterState(uint256 _tokenId)
        external
        view
        returns (uint256 status)
    {
        // housesStates = [
        //     0 : "doesn't_exist",
        //     1 : "under_construction",
        //     2 : "open",
        //     3 : "under_destroyment",
        //     4 : "destroyed"
        // ];
        uint256 maturityTime = trainingDetails[_tokenId].maturityTime;
        if (maturityTime == 0) {
            if (_tokenId <= ITrain.getPreMintNumber()) {
                status = 2;
            } else {
                status = 0;
            }
        } else {
            if (block.timestamp < maturityTime) {
                status = 1;
            } else {
                if (closingProcesses[1][_tokenId].isClosing) {
                    status = 3;
                }
                if (closingProcesses[1][_tokenId].destructed) {
                    status = 4;
                } else {
                    status = 2;
                }
            }
        }
    }

    function getLaboratoryState(uint256 _tokenId)
        external
        view
        returns (uint256 status)
    {
        // housesStates = [
        //     0 : "doesn't_exist",
        //     1 : "under_construction",
        //     2 : "open",
        //     3 : "under_destroyment",
        //     4 : "destroyed"
        // ];
        uint256 maturityTime = laboratoryDetails[_tokenId].maturityTime;
        if (maturityTime == 0) {
            if (_tokenId <= ILab.getPreMintNumber()) {
                status = 2;
            } else {
                status = 0;
            }
        } else {
            if (block.timestamp < maturityTime) {
                status = 1;
            } else {
                if (closingProcesses[2][_tokenId].isClosing) {
                    status = 3;
                }
                if (closingProcesses[2][_tokenId].destructed) {
                    status = 4;
                } else {
                    status = 2;
                }
            }
        }
    }

    function getTrainingCenterMaturityTime(uint256 _tokenId)
        external
        view
        returns (uint256)
    {
        return trainingDetails[_tokenId].maturityTime;
    }

    function getLaboMaturityTime(uint256 _tokenId)
        external
        view
        returns (uint256)
    {
        return laboratoryDetails[_tokenId].maturityTime;
    }

    function canTrain(uint256 _tokenId) external view returns (bool) {
        bool result;
        if (_tokenId != 0 && _tokenId <= ITrain.getPreMintNumber()) {
            result = true;
        } else if (
            trainingDetails[_tokenId].maturityTime == 0 ||
            block.timestamp < trainingDetails[_tokenId].maturityTime ||
            closingProcesses[1][_tokenId].isClosing ||
            closingProcesses[1][_tokenId].destructed
        ) {
            result = false;
        } else {
            result = true;
        }

        return result;
    }

    function canLaboSell(uint256 _tokenId) external view returns (bool) {
        bool result;
        if (_tokenId != 0 && _tokenId <= ILab.getPreMintNumber()) {
            result = true;
        } else if (
            laboratoryDetails[_tokenId].maturityTime == 0 ||
            block.timestamp < laboratoryDetails[_tokenId].maturityTime ||
            closingProcesses[2][_tokenId].isClosing ||
            closingProcesses[2][_tokenId].destructed
        ) {
            result = false;
        } else {
            result = true;
        }

        return result;
    }

    function closeTrainingCenter(uint256 _tokenId) external {
        require(
            _tokenId > ITrain.getPreMintNumber(),
            "This center can't be closed"
        );
        ClosingProcess storage c = closingProcesses[1][_tokenId];
        require(ITrain.ownerOf(_tokenId) == msg.sender, "not your Center");
        require(!c.isClosing, "Already in closing process");

        c.isClosing = true;
        c.timestampClosedActed = block.timestamp + closingHousesDuration;

        require(ITrainMan.cleanSlotsBeforeClosing(_tokenId));
    }

    function getBZAIBackFromClosingTraining(uint256 _tokenId) external {
        ClosingProcess storage c = closingProcesses[1][_tokenId];
        require(ITrain.ownerOf(_tokenId) == msg.sender, "not your Center");
        require(c.isClosing, "Not in closing process");
        require(
            block.timestamp >= c.timestampClosedActed,
            "Closing process not finished, please wait "
        );
        uint256 _amount = trainingDetails[_tokenId].lockedInCenter;
        trainingDetails[_tokenId].lockedInCenter = 0;

        //Burn
        c.isClosing = false;
        c.destructed = true;

        require(LP.transfer(msg.sender, _amount));
        ITrain.burn(_tokenId);
    }

    function closeLabo(uint256 _tokenId) public {
        require(
            _tokenId > ILab.getPreMintNumber(),
            "This center can't be closed"
        );
        ClosingProcess storage c = closingProcesses[2][_tokenId];
        require(ILab.ownerOf(_tokenId) == msg.sender, "Not your labo");
        require(!c.isClosing, "Already in closing process");

        c.isClosing = true;
        c.timestampClosedActed = block.timestamp + closingHousesDuration;
        require(ILabMan.cleanSlotsBeforeClosing(_tokenId));
    }

    function getBZAIBackFromClosingLabo(uint256 _tokenId) public {
        ClosingProcess storage c = closingProcesses[2][_tokenId];
        require(ILab.ownerOf(_tokenId) == msg.sender, "Not your labo");
        require(c.isClosing, "Not in closing process");
        require(
            block.timestamp >= c.timestampClosedActed,
            "Closing process during Not finished, please wait "
        );
        uint256 amount = laboratoryDetails[_tokenId].lockedInCenter;
        laboratoryDetails[_tokenId].lockedInCenter = 0;

        c.isClosing = false;
        c.destructed = true;

        require(LP.transfer(msg.sender, amount));
        ILab.burn(_tokenId);
    }
}
