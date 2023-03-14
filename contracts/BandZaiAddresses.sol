// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// Master contract use update contract addresses

contract BandzaiAddresses is Ownable {
    uint256 constant TIMELOCK_PERIOD = 1 days;
    uint256 public deploymentTimestamp;

    struct ContractInitialisation {
        address currentAddress;
        address pendingAddress;
        uint256 pendingUnlockTime;
    }

    mapping(AddressesInit.Addresses => ContractInitialisation) public addresses;

    string[] contractName = [
        "ALCHEMY",
        "BZAI_TOKEN",
        "CHICKEN",
        "CLAIM_NFTS",
        "DELEGATE",
        "EGGS_NFT",
        "FIGHT",
        "FIGHT_PVP",
        "IPFS_STORAGE",
        "LABO_MANAGEMENT",
        "LABO_NFT",
        "LEVEL_STORAGE",
        "LOOT",
        "MARKET_PLACE",
        "MARKET_DUTCH_AUCTION_ZAI",
        "NURSERY_MANAGEMENT",
        "NURSERY_NFT",
        "OPEN_AND_CLOSE",
        "ORACLE",
        "PAYMENTS",
        "POTIONS_NFT",
        "PVP_GAME",
        "RANKING",
        "RENT_MY_NFT",
        "REWARDS_PVP",
        "REWARDS_WINNING_PVE",
        "REWARDS_RANKING",
        "TRAINING_MANAGEMENT",
        "TRAINING_NFT",
        "ZAI_META",
        "ZAI_NFT"
    ];

    event ContractSetted(
        AddressesInit.Addresses indexed contractSetted,
        string indexed contractNameSetted,
        address newAddress
    );

    event ContractUpdateinitialized(
        AddressesInit.Addresses indexed contractInitiate,
        string indexed contractNameSetted,
        address newAddress
    );
    event ContractUpdateCanceled(
        AddressesInit.Addresses indexed contractInitiateCanceled,
        string indexed contractNameSetted,
        address addressCanceled
    );
    event ContractUpdated(
        AddressesInit.Addresses indexed contractUpdated,
        string indexed contractNameSetted,
        address oldAddress,
        address newAddress
    );

    constructor() {
        deploymentTimestamp = block.timestamp;
    }

    modifier addressAndNameMatch(
        AddressesInit.Addresses _contract,
        string memory _contractName,
        address _addr
    ) {
        require(_addr != address(0), "Address can't be 0x0");
        require(
            keccak256(bytes(contractName[uint256(_contract)])) ==
                keccak256(bytes(_contractName)),
            "Error in contract name "
        );
        _;
    }

    modifier initializationCheck(
        AddressesInit.Addresses _contract,
        string memory _contractName
    ) {
        require(
            addresses[_contract].pendingAddress != address(0) &&
                addresses[_contract].pendingUnlockTime != 0,
            "There is no pending initialization for this contract"
        );
        require(
            keccak256(bytes(contractName[uint256(_contract)])) ==
                keccak256(bytes(_contractName)),
            "Error in contract name "
        );
        _;
    }

    function getAddressOf(AddressesInit.Addresses _contract)
        external
        view
        returns (address)
    {
        return addresses[_contract].currentAddress;
    }

    function isAuthToManagedNFTs(address _address)
        external
        view
        returns (bool)
    {
        return (_address ==
            addresses[AddressesInit.Addresses.NURSERY_MANAGEMENT]
                .currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.TRAINING_MANAGEMENT]
                .currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.LABO_MANAGEMENT].currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.EGGS_NFT].currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.MARKET_DUTCH_AUCTION_ZAI]
                .currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.ALCHEMY].currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.FIGHT].currentAddress ||
            _address == addresses[AddressesInit.Addresses.LOOT].currentAddress);
    }

    function isAuthToManagedPayments(address _address)
        external
        view
        returns (bool)
    {
        return (_address ==
            addresses[AddressesInit.Addresses.LABO_MANAGEMENT].currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.MARKET_DUTCH_AUCTION_ZAI]
                .currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.NURSERY_MANAGEMENT]
                .currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.TRAINING_MANAGEMENT]
                .currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.FIGHT].currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.RANKING].currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.MARKET_PLACE].currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.EGGS_NFT].currentAddress ||
            _address ==
            addresses[AddressesInit.Addresses.POTIONS_NFT].currentAddress);
    }

    function setAddress(
        AddressesInit.Addresses _contract,
        string memory _contractName,
        address _addr
    ) external onlyOwner addressAndNameMatch(_contract, _contractName, _addr) {
        if (_contract == AddressesInit.Addresses.PVP_GAME) {
            require(
                block.timestamp >= deploymentTimestamp + 183 days,
                "Only 6 months after TGE"
            );
        }

        require(
            addresses[_contract].currentAddress == address(0),
            "Contract already setted plz use initializeAddress"
        );
        addresses[_contract].currentAddress = _addr;
        emit ContractSetted(_contract, contractName[uint256(_contract)], _addr);
    }

    function initializeAddress(
        AddressesInit.Addresses _contract,
        string memory _contractName,
        address _addr
    ) external onlyOwner addressAndNameMatch(_contract, _contractName, _addr) {
        ContractInitialisation storage c = addresses[_contract];
        require(
            c.pendingAddress == address(0) && c.pendingUnlockTime == 0,
            "An initialization is already pending plz cancel old one before init a new one"
        );

        c.pendingAddress = _addr;
        c.pendingUnlockTime = block.timestamp + TIMELOCK_PERIOD;

        emit ContractUpdateinitialized(
            _contract,
            contractName[uint256(_contract)],
            _addr
        );
    }

    function cancelInitialization(
        AddressesInit.Addresses _contract,
        string memory _contractName
    ) external onlyOwner initializationCheck(_contract, _contractName) {
        ContractInitialisation storage c = addresses[_contract];

        address _pendingAddress = c.pendingAddress;
        c.pendingAddress = address(0);
        c.pendingUnlockTime = 0;

        emit ContractUpdateCanceled(
            _contract,
            contractName[uint256(_contract)],
            _pendingAddress
        );
    }

    function updateContract(
        AddressesInit.Addresses _contract,
        string memory _contractName
    ) external onlyOwner initializationCheck(_contract, _contractName) {
        require(
            block.timestamp >= addresses[_contract].pendingUnlockTime,
            "Time lock period didn't expired"
        );

        ContractInitialisation storage c = addresses[_contract];

        address _oldAddress = c.currentAddress;
        c.currentAddress = c.pendingAddress;
        c.pendingAddress = address(0);
        c.pendingUnlockTime = 0;
        _updateAllInterfaces();

        emit ContractUpdated(
            _contract,
            _contractName,
            _oldAddress,
            c.currentAddress
        );
    }

    // UPDATE AUDIT : function allowing update of all interfaces/addresses of protocole contract
    // This function is called after deployment for finalizing setting of protocole
    // This function is automaticly called by MasterUpdater when an address is updated
    function updateAllInterfaces() external {
        _updateAllInterfaces();
    }

    function _updateAllInterfaces() internal {
        IZaiMeta(addresses[AddressesInit.Addresses.ZAI_META].currentAddress)
            .updateInterfaces();
        IipfsIdStorage(
            addresses[AddressesInit.Addresses.IPFS_STORAGE].currentAddress
        ).updateInterfaces();
        ILaboratory(addresses[AddressesInit.Addresses.LABO_NFT].currentAddress)
            .updateInterfaces();
        ILabManagement(
            addresses[AddressesInit.Addresses.LABO_MANAGEMENT].currentAddress
        ).updateInterfaces();
        ITraining(
            addresses[AddressesInit.Addresses.TRAINING_NFT].currentAddress
        ).updateInterfaces();
        ITrainingManagement(
            addresses[AddressesInit.Addresses.TRAINING_MANAGEMENT]
                .currentAddress
        ).updateInterfaces();
        INurseryManagement(
            addresses[AddressesInit.Addresses.NURSERY_MANAGEMENT].currentAddress
        ).updateInterfaces();
        IPotions(addresses[AddressesInit.Addresses.POTIONS_NFT].currentAddress)
            .updateInterfaces();
        IOpenAndClose(
            addresses[AddressesInit.Addresses.OPEN_AND_CLOSE].currentAddress
        ).updateInterfaces();
        IFighting(addresses[AddressesInit.Addresses.FIGHT].currentAddress)
            .updateInterfaces();
        ILevelStorage(
            addresses[AddressesInit.Addresses.LEVEL_STORAGE].currentAddress
        ).updateInterfaces();
        IRewardsWinningFound(
            addresses[AddressesInit.Addresses.REWARDS_WINNING_PVE]
                .currentAddress
        ).updateInterfaces();
        IRewardsRankingFound(
            addresses[AddressesInit.Addresses.REWARDS_RANKING].currentAddress
        ).updateInterfaces();
        IRewardsPvP(
            addresses[AddressesInit.Addresses.REWARDS_PVP].currentAddress
        ).updateInterfaces();
        IRanking(addresses[AddressesInit.Addresses.RANKING].currentAddress)
            .updateInterfaces();
        IDelegate(addresses[AddressesInit.Addresses.DELEGATE].currentAddress)
            .updateInterfaces();
        ILootProgress(addresses[AddressesInit.Addresses.LOOT].currentAddress)
            .updateInterfaces();
        IMarket(
            addresses[AddressesInit.Addresses.MARKET_DUTCH_AUCTION_ZAI]
                .currentAddress
        ).updateInterfaces();
        IAlchemy(addresses[AddressesInit.Addresses.ALCHEMY].currentAddress)
            .updateInterfaces();
    }
}
