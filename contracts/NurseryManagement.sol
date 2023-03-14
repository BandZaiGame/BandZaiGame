// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// Nursery is where eggs are created.
// Each Nurseries can create 5 bronze eggs by day.
// after 5th bronze is sold, silver egg can be sold with a delay of 24h
// during this delay , owner of nursery can "reserve" this egg for himself ,
// but he have to burn average price of all nurseries egg state price.
// when an egg is sold it is transfered to buyer wallet, and it can be scratched(and a zai born) after the maturity duration
contract NurseryManagement is Ownable {
    INurseryNFT immutable INurs;
    IAddresses public gameAddresses;
    IPayments public IPay;
    IEggs public Eggs;
    address public claimNFTs;

    uint256 public preMintNumber;

    uint256[4] _minPrices = [100 * 1E18, 200 * 1E18, 500 * 1E18, 1000 * 1E18];
    uint256[4] _maxPrices = [
        100000 * 1E18,
        200000 * 1E18,
        500000 * 1E18,
        1000000 * 1E18
    ];

    uint256[4] public maturities = [1 days, 3 days, 7 days, 14 days];

    // UPDATE AUDIT: allow adjust timing for minting egg n+1
    uint256 public timeForNextEgg = 57600; // 16h

    struct NurseryDetails {
        uint256 revenues;
        ZaiStruct.MintedData mintedDatas;
        ZaiStruct.MintedData tempCounterDatas;
        ZaiStruct.EggsPrices eggsPrices;
        uint8 nextStateToMint; // 0 bronze ; 1 Silver ; 2 Gold ; 3 Platinum
        uint32 nextUnlock; // use for prevent minting
        uint32 lastTimeReserveEgg; // preventing nursery owner reserve one egg per day max
    }
    mapping(uint256 => NurseryDetails) public nurseryDetails;

    event EggSold(
        address indexed nurseryOwner,
        address indexed buyer,
        uint256 eggId,
        uint256 price,
        uint256 eggType
    );
    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(address payments, address eggs);
    event MaturityChanged(
        uint256 indexed state,
        uint256 oldMaturity,
        uint256 newMaturity
    );
    event MinPricesChanged(uint256[4] oldPrices, uint256[4] newPrices);
    event MaxPricesChanged(uint256[4] oldPrices, uint256[4] newPrices);
    event UnactiveEggsPricesUpdated(uint256[4] oldPrices, uint256[4] newPrices);
    event TimeForNextEgg(uint256 oldMetric, uint256 newMetric);
    event EggReserved(
        uint256 indexed nurseryId,
        address nurseryOwner,
        address reserveFor,
        uint256 eggId,
        uint256 eggType
    );

    constructor(INurseryNFT nursery) {
        INurs = nursery;
        preMintNumber = INurs.totalSupply();
        for (uint256 i = 1; i <= preMintNumber; ) {
            nurseryDetails[i].eggsPrices = ZaiStruct.EggsPrices(
                1000 * 1E18,
                5000 * 1E18,
                10000 * 1E18,
                100000 * 1E18
            );
            unchecked {
                ++i;
            }
        }
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
        IPay = IPayments(
            gameAddresses.getAddressOf(AddressesInit.Addresses.PAYMENTS)
        );
        Eggs = IEggs(
            gameAddresses.getAddressOf(AddressesInit.Addresses.EGGS_NFT)
        );
        claimNFTs = gameAddresses.getAddressOf(
            AddressesInit.Addresses.CLAIM_NFTS
        );
        emit InterfacesUpdated(address(IPay), address(Eggs));
    }

    // UPDATE AUDIT : allow owner to change prices of eggs in inactive nurseries when price in dutch auction (MarketZai) are not relevent
    function updateEggsPriceForUnactiveNurseries(uint256[4] calldata prices)
        external
        onlyOwner
    {
        uint256[4] memory _oldPrices;
        for (uint256 i = 1; i <= preMintNumber; ) {
            if (INurs.ownerOf(i) == claimNFTs) {
                nurseryDetails[i].eggsPrices = ZaiStruct.EggsPrices(
                    prices[0] * 1E18,
                    prices[1] * 1E18,
                    prices[2] * 1E18,
                    prices[3] * 1E18
                );
            }
            unchecked {
                ++i;
            }
        }
        emit UnactiveEggsPricesUpdated(_oldPrices, prices);
    }

    function setMaturityDurations(uint256 _state, uint256 _numberOfDays)
        external
        onlyOwner
    {
        require(_state < 4, "Doesn't exist");
        require(_numberOfDays >= 1 && _numberOfDays <= 60, "Not good range");
        uint256 _oldMaturity = maturities[_state];

        maturities[_state] = _numberOfDays * 1 days;
        emit MaturityChanged(_state, _oldMaturity, maturities[_state]);
    }

    // UPDATE AUDIT: allow adjust timing for minting egg n+1
    function setTimeForNextEgg(uint256 _timeForNextEgg) external onlyOwner {
        uint256 oldMetric = timeForNextEgg;
        timeForNextEgg = _timeForNextEgg;
        emit TimeForNextEgg(oldMetric, timeForNextEgg);
    }

    function _canMint(uint256 _tokenId) internal view returns (bool) {
        return INurs.ownerOf(_tokenId) != claimNFTs;
    }

    function getNurseryDetails(uint256 _tokenId)
        external
        view
        returns (NurseryDetails memory)
    {
        return nurseryDetails[_tokenId];
    }

    function getMinPrices() external view returns (uint256[4] memory) {
        return _minPrices;
    }

    function setMinPrices(uint256[4] memory _prices) external onlyOwner {
        uint256[4] memory _oldPrices = _minPrices;
        _minPrices = _prices;
        emit MinPricesChanged(_oldPrices, _prices);
    }

    function setMaxPrices(uint256[4] memory _prices) external onlyOwner {
        uint256[4] memory _oldPrices = _maxPrices;
        _maxPrices = _prices;
        emit MaxPricesChanged(_oldPrices, _prices);
    }

    function getEggsPrices(uint256 _tokenId)
        external
        view
        returns (ZaiStruct.EggsPrices memory)
    {
        return nurseryDetails[_tokenId].eggsPrices;
    }

    function _updateNextMint(uint256 _tokenId, uint256 state) internal {
        require(
            state == nurseryDetails[_tokenId].nextStateToMint,
            "State has changed since tx began"
        );
        ZaiStruct.MintedData storage temp = nurseryDetails[_tokenId]
            .tempCounterDatas;
        ZaiStruct.MintedData storage total = nurseryDetails[_tokenId]
            .mintedDatas;
        uint256 _next;

        if (temp.bronzeMinted < 5) {
            ++temp.bronzeMinted;
            ++total.bronzeMinted;
            if (temp.bronzeMinted == 5) {
                _next = 1;
                nurseryDetails[_tokenId].nextUnlock = uint32(
                    block.timestamp + timeForNextEgg
                ); // UPDATE AUDIT: allow adjust timing for minting egg n+1
            }
            if (temp.bronzeMinted == 5 && temp.silverMinted == 5) {
                _next = 2;
                nurseryDetails[_tokenId].nextUnlock = uint32(
                    block.timestamp + timeForNextEgg
                ); // UPDATE AUDIT: allow adjust timing for minting egg n+1
            }
            if (
                temp.bronzeMinted == 5 &&
                temp.silverMinted == 5 &&
                temp.goldMinted == 5
            ) {
                _next = 3;
                nurseryDetails[_tokenId].nextUnlock = uint32(
                    block.timestamp + timeForNextEgg
                ); // UPDATE AUDIT: allow adjust timing for minting egg n+1
            }
        } else if (temp.silverMinted < 5) {
            ++temp.silverMinted;
            ++total.silverMinted;
            temp.bronzeMinted = 0;
        } else if (temp.goldMinted < 5) {
            ++temp.goldMinted;
            ++total.goldMinted;
            temp.bronzeMinted = 0;
            temp.silverMinted = 0;
        } else {
            ++temp.platinumMinted;
            ++total.platinumMinted;
            temp.bronzeMinted = 0;
            temp.silverMinted = 0;
            temp.goldMinted = 0;
        }
        nurseryDetails[_tokenId].nextStateToMint = uint8(_next);
    }

    function setPrice(
        uint256 _tokenId,
        uint256 _state,
        uint256 price
    ) external {
        require(INurs.ownerOf(_tokenId) == msg.sender, "Not your nurs");
        require(_state <= 3, "State doesn't exist");
        require(price >= _minPrices[_state], "price too low");
        require(price <= _maxPrices[_state], "price too high");
        ZaiStruct.EggsPrices storage e = nurseryDetails[_tokenId].eggsPrices;

        if (_state == 0) {
            e.bronzePrice = price;
        } else if (_state == 1) {
            e.silverPrice = price;
        } else if (_state == 2) {
            e.goldPrice = price;
        } else if (_state == 3) {
            e.platinumPrice = price;
        }
    }

    function buyEgg(
        uint256 _tokenId,
        uint256 state,
        uint256 _maxPrice
    ) external returns (uint256 eggId) {
        require(_canMint(_tokenId), "Nurs can't mint egg yet");
        require(
            state == nurseryDetails[_tokenId].nextStateToMint,
            "Not the good state"
        );
        require(
            block.timestamp >= nurseryDetails[_tokenId].nextUnlock,
            "To soon to mint"
        );
        _updateNextMint(_tokenId, state);
        uint256 _price = _getEggsPrice(state, _tokenId);

        require(_maxPrice >= _price, "Price changed");
        require(IPay.payWithRewardOrWallet(msg.sender, _price));

        address _owner = INurs.ownerOf(_tokenId);
        require(IPay.payOwner(_owner, _price));

        nurseryDetails[_tokenId].revenues += _price;

        eggId = Eggs.mintEgg(msg.sender, state, maturities[state]);
        emit EggSold(_owner, msg.sender, eggId, _price, state);
    }

    function reserveNextEgg(uint256 _tokenId, address _to)
        external
        returns (uint256 eggId)
    {
        require(
            msg.sender == INurs.ownerOf(_tokenId),
            "only nursery owner can reserve next egg"
        );
        require(
            nurseryDetails[_tokenId].lastTimeReserveEgg <
                block.timestamp + 1 days,
            "You can reserve only one egg by day"
        );
        uint256[4] memory averagePrices = _getZaiPriceAverage();
        nurseryDetails[_tokenId].lastTimeReserveEgg = uint32(block.timestamp);
        uint256 state = nurseryDetails[_tokenId].nextStateToMint;

        require(
            IPay.burnRevenuesForEggs(msg.sender, averagePrices[state]),
            "Your center doesn't have enough balance"
        );

        _updateNextMint(_tokenId, state);

        eggId = Eggs.mintEgg(
            _to,
            state,
            maturities[state] * 2 // UPDATE AUDIT: fixing duration => delete block.timestamp
        );
        emit EggReserved(_tokenId, msg.sender, _to, eggId, state);
    }

    function _getEggsPrice(uint256 _state, uint256 _tokenId)
        internal
        view
        returns (uint256 price)
    {
        ZaiStruct.EggsPrices memory e = nurseryDetails[_tokenId].eggsPrices;
        if (_state == 0) {
            price = e.bronzePrice;
        } else if (_state == 1) {
            price = e.silverPrice;
        } else if (_state == 2) {
            price = e.goldPrice;
        } else if (_state == 3) {
            price = e.platinumPrice;
        }
    }

    function _getZaiPriceAverage() internal view returns (uint256[4] memory) {
        uint256[4] memory _prices;
        for (uint256 i = 1; i <= preMintNumber; ) {
            ZaiStruct.EggsPrices memory eggs = nurseryDetails[i].eggsPrices;
            _prices[0] += eggs.bronzePrice;
            _prices[1] += eggs.silverPrice;
            _prices[2] += eggs.goldPrice;
            _prices[3] += eggs.platinumPrice;

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < 4; ) {
            _prices[i] /= preMintNumber;
            unchecked {
                ++i;
            }
        }
        return _prices;
    }
}
