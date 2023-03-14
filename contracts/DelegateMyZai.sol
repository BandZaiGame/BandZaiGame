// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// scholarship contract
// player can delegate his Zai
contract DelegateMyZai is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.UintSet private inDelegationProcess;

    mapping(address => EnumerableSet.UintSet) private ownerDelegated;
    mapping(address => EnumerableSet.UintSet) private scholarDelegated;

    mapping(uint256 => ZaiStruct.DelegateData) _delegateDatas;

    IAddresses public gameAddresses;
    // UPDATE AUDIT : store IGuildeDelegation ,IZaiNFT && fightAddress
    IGuildeDelegation public IGuilde;
    IZaiNFT immutable IZai;
    address public fightAddress;

    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address guildeDelegationAddress,
        address fightAddress
    );
    event ZaiDelegated(
        uint256 indexed zaiId,
        address indexed scholar,
        address owner,
        uint256 delegationEnd
    );
    event ZaiInDelegation(
        uint256 indexed zaiId,
        address indexed owner,
        uint256 percentageForScholar,
        uint256 duration
    );
    event DelegationStopped(uint256 indexed zaiId);
    event DelegationEnded(uint256 indexed zaiId, address indexed scholar);

    constructor(IZaiNFT _IZai) {
        IZai = _IZai;
    }

    modifier onlyZaiOwner(uint256 _zaiId) {
        require(IZai.ownerOf(_zaiId) == msg.sender, "Not your zai");
        _;
    }

    modifier onlyFight() {
        require(fightAddress == msg.sender, "Address not accepted");
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

    // UPDATE AUDIT : store IGuildeDelegation
    function updateInterfaces() external {
        IGuilde = IGuildeDelegation(
            gameAddresses.getAddressOf(AddressesInit.Addresses.RENT_MY_NFT)
        );
        fightAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.FIGHT
        );
        emit InterfacesUpdated(address(IGuilde), fightAddress);
    }

    function getinDelegationProcessNumber() external view returns (uint256) {
        return inDelegationProcess.length();
    }

    // UPDATE AUDIT : add _startIndex and _quantity
    // to return a page with _quantity ZaiId in delegation
    function getZaisInDelegation(uint256 _startIndex, uint256 _quantity)
        external
        view
        returns (uint256[] memory)
    {
        uint256 length = inDelegationProcess.length();
        if (_startIndex + _quantity > length) {
            _quantity = length - _startIndex;
        }
        uint256[] memory list = new uint256[](_quantity);
        for (uint256 i = _startIndex; i < _startIndex + _quantity; ) {
            if (i >= length) {
                break;
            }
            list[i - _startIndex] = inDelegationProcess.at(i);

            unchecked {
                ++i;
            }
        }
        return list;
    }

    // UPDATE AUDIT :no need pagination to get scholar's zai , because a scholar is limited to 5 ZAIs in delegation

    function getDelegatedToScholar(address _scholar)
        external
        view
        returns (uint256[] memory)
    {
        uint256 length = scholarDelegated[_scholar].length();
        uint256[] memory list = new uint256[](length);

        for (uint256 i; i < length; ) {
            list[i] = scholarDelegated[_scholar].at(i);

            unchecked {
                ++i;
            }
        }
        return list;
    }

    function isZaiDelegated(uint256 _zaiId) external view returns (bool) {
        if (
            _delegateDatas[_zaiId].scholarAddress != address(0x0) &&
            !_isFreeForScholar(_zaiId)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function getDelegateDatasByZai(uint256 _zaiId)
        external
        view
        returns (ZaiStruct.DelegateData memory)
    {
        require(_zaiId != 0, "Zai doesn't exist");
        return (_delegateDatas[_zaiId]);
    }

    function isFreeForScholar(uint256 _zaiId) external view returns (bool) {
        return _isFreeForScholar(_zaiId);
    }

    function _isFreeForScholar(uint256 _zaiId) internal view returns (bool) {
        if (!inDelegationProcess.contains(_zaiId)) {
            return false;
        } else {
            return !_gotSchoolarActive(_zaiId);
        }
    }

    function _gotSchoolarActive(uint256 _zaiId) internal view returns (bool) {
        ZaiStruct.DelegateData storage m = _delegateDatas[_zaiId];
        if (m.scholarAddress == address(0x0)) {
            return false;
        } else if (block.timestamp >= m.contractEnd) {
            return false;
        } else if (block.timestamp - m.lastScholarPlayed >= 1 days) {
            return false;
        } else {
            return true;
        }
    }

    // Possible to open a Zai to delegation to anyone want to take it (by setting _scholar to address(0x0)) or to assign to a specific address
    function openMyZaiToDelegation(
        uint256 _zaiId,
        uint256 _percentageForScholar,
        uint256 _contractDuration,
        address _scholar
    ) external onlyZaiOwner(_zaiId) {
        require(
            _contractDuration >= 3 && _contractDuration <= 180,
            "min 3 days, max 180 days"
        ); // UPDATE AUDIT: max change 30 to 180
        require(
            _percentageForScholar >= 10 && _percentageForScholar <= 90,
            "min 10 %, max 90 %"
        );

        ZaiStruct.DelegateData storage m = _delegateDatas[_zaiId];
        require(
            !_gotSchoolarActive(_zaiId),
            "Can't modify when contract is active"
        );
        if (!m.renewable) {
            m.renewable = true;
        }
        if (!inDelegationProcess.contains(_zaiId)) {
            inDelegationProcess.add(_zaiId);
        }
        if (!ownerDelegated[msg.sender].contains(_zaiId)) {
            ownerDelegated[msg.sender].add(_zaiId);
        }

        if (_scholar != address(0x0)) {
            // UPDATE AUDIT: Limit quantity of zai to 5
            require(
                EnumerableSet.length(scholarDelegated[_scholar]) < 5,
                "Can't have more than 5 Zai in delegation"
            );
            if (m.scholarAddress != address(0x0)) {
                scholarDelegated[m.scholarAddress].remove(_zaiId);
            }

            m.contractEnd = uint32(
                block.timestamp + (_contractDuration * 1 days)
            );
            m.lastScholarPlayed = uint32(block.timestamp);
            m.scholarAddress = _scholar;
            scholarDelegated[_scholar].add(_zaiId);
        }

        m.ownerAddress = msg.sender;
        m.contractDuration = uint32(_contractDuration * 1 days);
        m.percentageForScholar = uint8(_percentageForScholar);
        emit ZaiInDelegation(
            _zaiId,
            msg.sender,
            _percentageForScholar,
            _contractDuration
        );
    }

    // when owner set UnRenewable, he will automaticly stop the delegation at end of the contract
    // It will be possible to setup a new delegation process or cancel delegation at contract end
    function setUnrenewable(uint256 _zaiId) external onlyZaiOwner(_zaiId) {
        require(
            ownerDelegated[msg.sender].contains(_zaiId),
            "Zai is not delegated"
        );
        _delegateDatas[_zaiId].renewable = false;
    }

    function cancelMyZaiDelegation(uint256 _zaiId)
        external
        onlyZaiOwner(_zaiId)
    {
        require(
            _isFreeForScholar(_zaiId),
            "Can't cancel delegation when contract is active"
        );

        ownerDelegated[msg.sender].remove(_zaiId);
        inDelegationProcess.remove(_zaiId);

        if (_delegateDatas[_zaiId].scholarAddress != address(0x0)) {
            scholarDelegated[_delegateDatas[_zaiId].scholarAddress].remove(
                _zaiId
            );
        }
        delete _delegateDatas[_zaiId];
        emit DelegationStopped(_zaiId);
    }

    // UPDATE AUDIT : a scholar can stop his delegation process
    function stopMyScholarship(uint256 _zaiId) external {
        ZaiStruct.DelegateData storage m = _delegateDatas[_zaiId];
        require(
            m.scholarAddress == msg.sender,
            "Not your scholarship instance"
        );
        scholarDelegated[msg.sender].remove(_zaiId);
        m.contractEnd = 0;
        m.lastScholarPlayed = 0;
        m.scholarAddress = address(0x0);

        emit DelegationEnded(_zaiId, msg.sender);
    }

    function updateLastScholarPlayed(uint256 _zaiId)
        external
        onlyFight
        returns (bool)
    {
        _delegateDatas[_zaiId].lastScholarPlayed = uint32(block.timestamp);
        return true;
    }

    function takeDelegation(uint256 _zaiId) external {
        // UPDATE AUDIT: Limit quantity of zai to 5
        require(
            scholarDelegated[msg.sender].length() < 5,
            "Can't have more than 5 Zai in delegation"
        );
        // UPDATE AUDIT: Can't take my personnal Zai in delegation
        require(IZai.ownerOf(_zaiId) != msg.sender, "This is your own Zai ! ");
        require(_isFreeForScholar(_zaiId), "Zai not free");

        ZaiStruct.DelegateData storage m = _delegateDatas[_zaiId];
        require(m.renewable, "Zai is not open to new delegation");

        if (m.scholarAddress != address(0x0)) {
            scholarDelegated[m.scholarAddress].remove(_zaiId);
            emit DelegationEnded(_zaiId, m.scholarAddress);
        }

        m.contractEnd = uint32(block.timestamp + m.contractDuration);
        m.lastScholarPlayed = uint32(block.timestamp);
        m.scholarAddress = msg.sender;
        scholarDelegated[msg.sender].add(_zaiId);
    }

    function renewDelegation(uint256 _zaiId) external {
        ZaiStruct.DelegateData storage m = _delegateDatas[_zaiId];
        require(
            m.scholarAddress == msg.sender,
            "You don't have delegation for this Zai"
        );
        require(m.renewable, "This contract is not renewable");
        require(
            block.timestamp >= m.contractEnd - 1 days,
            "Renewable is possible only 1 days before contract end"
        );
        m.contractEnd += m.contractDuration;
    }

    function kickScholar(uint256 _zaiId) external onlyZaiOwner(_zaiId) {
        ZaiStruct.DelegateData storage m = _delegateDatas[_zaiId];
        require(
            (m.lastScholarPlayed != 0 &&
                block.timestamp - m.lastScholarPlayed >= 1 days) ||
                block.timestamp >= m.contractEnd,
            "Scholar have used your zai during last 24h Or contract not ended"
        );
        scholarDelegated[m.scholarAddress].remove(_zaiId);
        address _scholar = m.scholarAddress;
        m.scholarAddress = address(0x0);
        m.lastScholarPlayed = 0;
        m.contractEnd = 0;
        emit DelegationEnded(_zaiId, _scholar);
    }

    function gotDelegationForZai(uint256 _zaiId)
        external
        view
        returns (ZaiStruct.ScholarDatas memory scholarDatas)
    {
        // UPDATE AUDIT : no need to get address
        if (address(IGuilde) != address(0x0)) {
            scholarDatas.guildeDatas = IGuilde.getRentingDatas(
                address(IZai),
                _zaiId
            );
        }

        scholarDatas.delegateDatas = _delegateDatas[_zaiId];
        if (
            scholarDatas.delegateDatas.ownerAddress == address(0x0) &&
            scholarDatas.guildeDatas.renterOf == address(0x0)
        ) {
            scholarDatas.delegateDatas.ownerAddress = IZai.ownerOf(_zaiId);
        }
    }

    // UPDATE AUDIT : fix rules
    function canUseZai(uint256 _zaiId, address _user)
        external
        view
        returns (bool)
    {
        address _owner = IZai.ownerOf(_zaiId);

        if (_owner == _user) {
            // if owner use his Zai and didn't opened any delegation process
            if (_delegateDatas[_zaiId].ownerAddress == address(0x0)) {
                return true;
            } else {
                if (_delegateDatas[_zaiId].scholarAddress == address(0x0)) {
                    return true;
                } else {
                    return false;
                }
            }
        } else if (
            // if _user is the scholar and contract doesn't end
            _delegateDatas[_zaiId].scholarAddress == _user &&
            block.timestamp < _delegateDatas[_zaiId].contractEnd
        ) {
            return true;
        } else if (address(IGuilde) != address(0x0)) {
            ZaiStruct.GuildeDatas memory _guildeData;
            _guildeData = IGuilde.getRentingDatas(address(IZai), _zaiId);
            if (_guildeData.renterOf == _user) {
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }
}
