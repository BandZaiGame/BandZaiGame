// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Interfaces.sol";

// MarketZai is where player can direct buy Zai from any state
// concept is a kind of dutchAuction where price of zais are average of egg sold in nurseries * by coeff
// each day price is divided by 2
// Ticket NFT will be used for marketing campain , owner of contract can mint a limit quantity of token in a period
// UPDATE AUDIT : add totalSupply() method

contract MarketZai is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 _totalSupply;

    IZaiNFT public IZai;
    IipfsIdStorage public Iipfs;
    IPayments public IPay;
    INurseryManagement public INursMan;
    IOracle public Oracle;

    uint256 public nurseriesPremintNumber;

    address public levelStorage;
    address public claimNFTsAddress;

    uint256 public ticketMintable = 30;
    // UPDATE AUDIT : There will be a Pre sale of 100 tickets season 0 (founders edition)
    uint256 public ticketSeason0 = 100;

    uint256 public blockPerDay = 17280; //testnet polygon = 17280 ::: mainNet 43200

    struct TicketCreationDate {
        uint256 randomDate;
        uint256 silverDate;
        uint256 goldDate;
        uint256 platinumDate;
    }

    TicketCreationDate public ticketCreationDate;

    struct TicketDatas {
        uint256 ticketType; //0 = random / 1 = silverTicket / 2 = goldTicket / 3 = platinumTicket
        uint256 season;
        uint256 mintingDate; // ticket can mint Zai during 60 days after is emission , after that period who know the utility of a ticket :D
    }

    mapping(uint256 => TicketDatas) public ticketDatas;

    IAddresses public gameAddresses;

    mapping(uint256 => uint256) _lastZaiSalesBlock;
    mapping(uint256 => uint256) _lastZaiSalesPrice;

    // bronze average X2 / silver average X 4 /  gold average X 16 / platinum average X 100 (meaning each 7 days a platinum is sold at nurseries average price )
    uint256[4] public dutchMultiplicators = [200, 400, 1600, 10000];

    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address zaiNFT,
        address levelStorage,
        address ipfsStorage,
        address payments,
        address claimAddress,
        uint256 nurseryPreMintNumber,
        address nurseryManagement,
        address oracle
    );
    event ZaiBorned(uint256 indexed state, uint256 zaiId, address owner);
    event UpdateBlockPerDay(uint256 oldData, uint256 newData);
    event MultiplicatorsSetted(
        uint256[4] oldMultiplicators,
        uint256[4] newMultiplicators
    );

    constructor() ERC721("Ticket_ZAI_NFT", "TICKET") {
        _lastZaiSalesBlock[0] = block.number;
        _lastZaiSalesBlock[1] = block.number;
        _lastZaiSalesBlock[2] = block.number;
        _lastZaiSalesBlock[3] = block.number;
        ticketCreationDate = TicketCreationDate(
            block.timestamp,
            block.timestamp,
            block.timestamp,
            block.timestamp
        );
    }

    function setGameAddresses(address _address) external onlyOwner {
        require(
            address(gameAddresses) == address(0x0),
            "game addresses already setted"
        );
        gameAddresses = IAddresses(_address);
        emit GameAddressesSetted(_address);
    }

    function setBlockPerDay(uint256 _blocks) external onlyOwner {
        uint256 _oldData = blockPerDay;
        blockPerDay = _blocks;
        emit UpdateBlockPerDay(_oldData, _blocks);
    }

    function updateInterfaces() external {
        IZai = IZaiNFT(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_NFT)
        );
        levelStorage = gameAddresses.getAddressOf(
            AddressesInit.Addresses.LEVEL_STORAGE
        );
        Iipfs = IipfsIdStorage(
            gameAddresses.getAddressOf(AddressesInit.Addresses.IPFS_STORAGE)
        );
        IPay = IPayments(
            gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
        );
        claimNFTsAddress = gameAddresses.getAddressOf(
            AddressesInit.Addresses.CLAIM_NFTS
        );
        nurseriesPremintNumber = INurseryNFT(
            gameAddresses.getAddressOf(AddressesInit.Addresses.NURSERY_NFT)
        ).totalSupply();
        INursMan = INurseryManagement(
            gameAddresses.getAddressOf(
                AddressesInit.Addresses.NURSERY_MANAGEMENT
            )
        );
        Oracle = IOracle(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ORACLE)
        );
        emit InterfacesUpdated(
            address(IZai),
            levelStorage,
            address(Iipfs),
            address(IPay),
            address(claimNFTsAddress),
            nurseriesPremintNumber,
            address(INursMan),
            address(Oracle)
        );
    }

    // function used to create challengers in level 0
    // that way fight can be done by the first Zai minted( id 11)
    function preMintZai() external onlyOwner {
        for (uint256 i; i < 10; ) {
            IZai.mintZai(levelStorage, "Challenger", 0);
            unchecked {
                ++i;
            }
        }
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function createTickets(uint256 _quantity) external onlyOwner {
        uint256 _toAdd = (block.timestamp - ticketCreationDate.randomDate) /
            1 days;
        ticketMintable += _toAdd;
        require(ticketMintable >= _quantity, "trying to mint too much ticket");
        ticketMintable -= _quantity;
        ticketCreationDate.randomDate = block.timestamp;
        uint256 _currentSeason = Iipfs.getCurrentSeason();
        uint256 _dateCreation = block.timestamp;
        for (uint256 i; i < _quantity; ) {
            _mintTicket(claimNFTsAddress, _currentSeason, _dateCreation, 0);
            unchecked {
                ++i;
            }
        }
        _mintSilverTicket(claimNFTsAddress, _currentSeason, _dateCreation);
        _mintGoldTicket(claimNFTsAddress, _currentSeason, _dateCreation);
        _mintPlatinumTicket(claimNFTsAddress, _currentSeason, _dateCreation);
    }

    // UPDATE AUDIT : There will be a Pre sale of season 0 (founders edition) all those Zai will be silver + stamped season 0
    function createSeasonZeroTickets(uint256 _quantity) external onlyOwner {
        require(ticketSeason0 >= _quantity, "trying to mint too much ticket");
        ticketSeason0 -= _quantity;

        uint256 _dateCreation = block.timestamp;
        for (uint256 i; i < _quantity; ) {
            _mintTicket(claimNFTsAddress, 0, _dateCreation, 1);
            unchecked {
                ++i;
            }
        }
    }

    function _mintSilverTicket(
        address _claimNFTsAddress,
        uint256 _currentSeason,
        uint256 _dateCreation
    ) internal {
        uint256 _silverToMint = (block.timestamp -
            ticketCreationDate.silverDate) / 5 days;
        if (_silverToMint != 0) {
            ticketCreationDate.silverDate = block.timestamp;
            for (uint256 i; i < _silverToMint; ) {
                _mintTicket(
                    _claimNFTsAddress,
                    _currentSeason,
                    _dateCreation,
                    1
                );
                unchecked {
                    ++i;
                }
            }
        }
    }

    function _mintGoldTicket(
        address _claimNFTsAddress,
        uint256 _currentSeason,
        uint256 _dateCreation
    ) internal {
        uint256 _goldToMint = (block.timestamp - ticketCreationDate.goldDate) /
            15 days;
        if (_goldToMint != 0) {
            ticketCreationDate.goldDate = block.timestamp;
            for (uint256 i; i < _goldToMint; ) {
                _mintTicket(
                    _claimNFTsAddress,
                    _currentSeason,
                    _dateCreation,
                    2
                );
                unchecked {
                    ++i;
                }
            }
        }
    }

    function _mintPlatinumTicket(
        address _claimNFTsAddress,
        uint256 _currentSeason,
        uint256 _dateCreation
    ) internal {
        uint256 _platinumToMint = (block.timestamp -
            ticketCreationDate.platinumDate) / 30 days;
        if (_platinumToMint != 0) {
            ticketCreationDate.platinumDate = block.timestamp;
            for (uint256 i; i < _platinumToMint; ) {
                _mintTicket(
                    _claimNFTsAddress,
                    _currentSeason,
                    _dateCreation,
                    3
                );
                unchecked {
                    ++i;
                }
            }
        }
    }

    function _mintTicket(
        address _address,
        uint256 _currentSeason,
        uint256 _dateCreation,
        uint256 _ticketType
    ) internal returns (uint256) {
        _tokenIds.increment();
        uint256 _newItemId = _tokenIds.current();
        _totalSupply++;
        ticketDatas[_newItemId] = TicketDatas(
            _ticketType,
            _currentSeason,
            _dateCreation
        );
        _safeMint(_address, _newItemId);

        return (_newItemId);
    }

    function useTicket(uint256 _ticketID, string memory _name)
        external
        returns (uint256)
    {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");
        require(ownerOf(_ticketID) == msg.sender, "Not your ticket");
        // UPDATE AUDIT : ticket season and zai season must matched
        uint256 _currentSeason = Iipfs.getCurrentSeason();
        TicketDatas memory _ticket = ticketDatas[_ticketID];
        require(_currentSeason == _ticket.season, "Ticket season isn't good");

        _burn(_ticketID);
        _totalSupply--;

        if (_ticket.ticketType == 0) {
            return (_randomMint(_name));
        } else {
            uint256 zaiId = _generateRandomZai(
                _name,
                msg.sender,
                _ticket.ticketType
            );
            emit ZaiBorned(_ticket.ticketType, zaiId, msg.sender);
            return zaiId;
        }
    }

    function _randomMint(string memory _name) internal returns (uint256 zaiId) {
        uint256 _random = Oracle.getRandom() % 10000;

        uint256 _state;
        if (_random < 100) {
            //1%
            _state = 3;
        } else if (_random >= 100 && _random < 600) {
            // 600 - 100 = 500 => 5%
            _state = 2;
        } else if (_random >= 600 && _random < 2000) {
            // 3000 - 800 = 2200 => 14%
            _state = 1;
        } else if (_random >= 2000) {
            // 80%
            _state = 0;
        }

        zaiId = _generateRandomZai(_name, msg.sender, _state);
        emit ZaiBorned(_state, zaiId, msg.sender);
    }

    function setMultiplicators(uint256[4] memory _dutchMultiplicators)
        external
        onlyOwner
    {
        require(
            _dutchMultiplicators[0] > 100 &&
                _dutchMultiplicators[1] > 200 &&
                _dutchMultiplicators[2] > 300 &&
                _dutchMultiplicators[3] > 500,
            "Values not good"
        );
        uint256[4] memory _oldMultiplicators = dutchMultiplicators;
        dutchMultiplicators = _dutchMultiplicators;
        emit MultiplicatorsSetted(_oldMultiplicators, _dutchMultiplicators);
    }

    // UPDATE AUDIT : replace buyBronzeZai, buySilverZai ... By only one function where state of Zai is in arguments
    function buyZai(
        uint256 _state,
        uint256 _maxPrice,
        string memory _name
    ) external returns (uint256 zaiId) {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");
        uint256 _price = _getZaiPrice(_state);
        require(_price <= _maxPrice, "Price changed !");

        _lastZaiSalesBlock[_state] = block.number;
        _lastZaiSalesPrice[_state] = _price;

        require(IPay.payWithRewardOrWallet(msg.sender, _price));
        IPay.distributeFees(_price);

        zaiId = _generateRandomZai(_name, msg.sender, _state);
        emit ZaiBorned(_state, zaiId, msg.sender);
    }

    // UPDATE AUDIT : return 4 prices for front end
    function getZaiPrice() external view returns (uint256[4] memory) {
        return [
            _getZaiPrice(0),
            _getZaiPrice(1),
            _getZaiPrice(2),
            _getZaiPrice(3)
        ];
    }

    function getLastZaiSaleDatas(uint256 _state)
        external
        view
        returns (uint256 price, uint256 blockNumber)
    {
        return (_lastZaiSalesPrice[_state], _lastZaiSalesBlock[_state]);
    }

    function _getZaiPrice(uint256 _state) internal view returns (uint256) {
        uint256 _price;

        for (uint256 i = 1; i <= nurseriesPremintNumber; ) {
            ZaiStruct.EggsPrices memory _eggPrices = INursMan.getEggsPrices(i);

            if (_state == 0) {
                _price +=
                    (_eggPrices.bronzePrice * dutchMultiplicators[0]) /
                    100;
            } else if (_state == 1) {
                _price +=
                    (_eggPrices.silverPrice * dutchMultiplicators[1]) /
                    100;
            } else if (_state == 2) {
                _price += (_eggPrices.goldPrice * dutchMultiplicators[2]) / 100;
            } else if (_state == 3) {
                _price +=
                    (_eggPrices.platinumPrice * dutchMultiplicators[3]) /
                    100;
            }

            unchecked {
                ++i;
            }
        }

        _price = _price / nurseriesPremintNumber;

        if (_price == 0) {
            _price == 1000000 * 1E18;
        }

        return _calculateDutchPrice(_state, _price);
    }

    function _calculateDutchPrice(uint256 _state, uint256 _price)
        internal
        view
        returns (uint256)
    {
        //calculate number of block past from the last sale
        uint256 _pastBlock = block.number - _lastZaiSalesBlock[_state];

        //calculate number of days past from the last sale
        uint256 _nbOfDaysPast = _pastBlock / blockPerDay;

        if (_nbOfDaysPast != 0) {
            // divide per 2 for each days past
            for (uint256 i; i < _nbOfDaysPast; ) {
                _price /= 2;
                unchecked {
                    ++i;
                }
            }
        }
        // calculate value to reduce for each block past (each days price is divide by 2)
        uint256 _toReducePerBlock = _price / blockPerDay / 2;

        // calculate number of block in the current day
        uint256 _pastBlockInCurrentDay = _pastBlock % blockPerDay;

        //reduce nber of block past in the day multiply by value to reduce per block
        _price -= (_pastBlockInCurrentDay * _toReducePerBlock);

        return (_price);
    }

    function _generateRandomZai(
        string memory _name,
        address _user,
        uint256 _state
    ) internal returns (uint256) {
        uint256 zaiId = IZai.mintZai(_user, _name, _state);
        return zaiId;
    }
}
