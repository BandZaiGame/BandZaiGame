// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces.sol";

// Proxy contract use to param all others contract addresses

contract BandzaiAddressesObsolete is Ownable {
    address immutable public masterSwitchContract;

    address alchemyAddress;
    address BZAITokenAddress;
    address challengeRewardsAddress;
    address chickenAddress;
    address claimNFTsAddress;
    address delegateZaiAddress;
    address eggsAddress;
    address fightAddress;
    address ipfsIdStorageAddress;
    address laboratoryAddress;
    address laboratoryNFTAddress;
    address levelStorageAddress;
    address lootAddress;
    address marketZaiAddress;
    address marketPlaceAddress;
    address nurseryManagementAddress;
    address nurseryNFTAddress;
    address oracleAddress;
    address openAndCloseAddress;
    address paymentsAddress;
    address potionAddress;
    address pvPAddress;
    address rankingContractAddress;
    address rentMyNFTAddress;
    address rewardsPvPAddress;
    address trainingAddress;
    address trainingNFTAddress;
    address winRewardsAddress;
    address zaiMetaAddress;
    address zaiNFTAddress;


    uint256 public deploymentTimestamp;

    event AddressUpdated(string indexed contractUpdated, address oldAddress, address newAddress);

    constructor(address master){
        deploymentTimestamp = block.timestamp;
        masterSwitchContract = master;
    }

    // UPDATE AUDIT : Addresses upgradabilty.
    // If address isn't setted, owner of contract can set it
    // Else only MasterUpdater (BandZaiAddressesUpdater.sol) can set with a 48h delay before validate the new address
    function _isOwner() view internal{
        if(msg.sender == owner()){
            return;
        }else{
            revert("address already setted or not owner");
        }
    }

    function _isMasterUpdater() view internal{
        if(msg.sender == masterSwitchContract){
            return;
        }else{
            revert("Only master switch can update address");
        }
    }

    function setBZAI(address _bzai) external {
        if(BZAITokenAddress == address(0)){
            _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = BZAITokenAddress;
        BZAITokenAddress = _bzai;
        emit AddressUpdated("BZAI", oldAddress, _bzai);
    }

    function setOracle(address _oracleAddress)
        external
    {
        if(oracleAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = oracleAddress;
        oracleAddress = _oracleAddress;
        emit AddressUpdated("ORACLE", oldAddress, _oracleAddress);
    }

    function setZaiNFT(address _zaiNFTAddress) external {
        if(zaiNFTAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = zaiNFTAddress;
        zaiNFTAddress = _zaiNFTAddress;
        emit AddressUpdated("ZAI_NFT", oldAddress, _zaiNFTAddress);
    }

    function setZaiMeta(address _address) external {
        if(zaiMetaAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = zaiMetaAddress;
        zaiMetaAddress = _address;
        emit AddressUpdated("ZAI_META", oldAddress, _address);
    }

    function setIpfsStorageAddress(address _ipfsIdStorageAddress)
        external
    {
        if(ipfsIdStorageAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = ipfsIdStorageAddress;
        ipfsIdStorageAddress = _ipfsIdStorageAddress;
        emit AddressUpdated("IPFS_STORAGE", oldAddress, _ipfsIdStorageAddress);
    }

    function setLaboratory(address _laboratoryAddress) external {
        if(laboratoryAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = laboratoryAddress;
        laboratoryAddress = _laboratoryAddress;
        emit AddressUpdated("LABORATORY_MANAGEMENT", oldAddress, _laboratoryAddress);
    }

    function setLaboratoryNFT(address _laboratoryAddress) external {
        if(laboratoryNFTAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = laboratoryNFTAddress;
        laboratoryNFTAddress = _laboratoryAddress;
        emit AddressUpdated("LABORATORY_NFT", oldAddress, _laboratoryAddress);
    }

    function setTrainingManagement(address _trainingAddress)
        external
    {
        if(trainingAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = trainingAddress;
        trainingAddress = _trainingAddress;
        emit AddressUpdated("TRAINING_MANAGEMENT", oldAddress, _trainingAddress);
    }

    function setTrainingNFT(address _trainingAddress) external {
        if(trainingNFTAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = trainingNFTAddress;
        trainingNFTAddress = _trainingAddress;
        emit AddressUpdated("TRAINING_NFT",oldAddress, _trainingAddress);
    }

    function setNurseryManagement(address _nurseryManAddress) external {
        if(nurseryManagementAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = nurseryManagementAddress;
        nurseryManagementAddress = _nurseryManAddress;
        emit AddressUpdated("NURSERY_MANAGEMENT", oldAddress, _nurseryManAddress);
    }

    function setNurseryNFT(address _nurseryNFTAddress) external {
        if(nurseryNFTAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = nurseryNFTAddress;
        nurseryNFTAddress = _nurseryNFTAddress;
        emit AddressUpdated("NURSERY_NFT",oldAddress, _nurseryNFTAddress);
    }

    function setPotion(address _potionAddress) external {
        if(potionAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = potionAddress;
        potionAddress = _potionAddress;
        emit AddressUpdated("POTIONS", oldAddress, _potionAddress);
    }

    function setFightAddress(address _fightAddress) external {
        if(fightAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = fightAddress;
        fightAddress = _fightAddress;
        emit AddressUpdated("FIGHT", oldAddress, _fightAddress);

    }

    function setEggsAddress(address _eggsAddress) external {
        if(eggsAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = eggsAddress;
        eggsAddress = _eggsAddress;
        emit AddressUpdated("EGGS", oldAddress, _eggsAddress);
    }

    function setMarketZaiAddress(address _marketZaiAddress) external {
        if(marketZaiAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = marketZaiAddress;
        marketZaiAddress = _marketZaiAddress;
        emit AddressUpdated("MARKET_ZAI", oldAddress, _marketZaiAddress);
    }

    function setPaymentsAddress(address _paymentsAddress) external {
        if(paymentsAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = paymentsAddress;
        paymentsAddress = _paymentsAddress;
        emit AddressUpdated("PAYMENT", oldAddress, _paymentsAddress);
    }

    function setChallengeRewardsAddress(address _address) external {
        if(challengeRewardsAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = challengeRewardsAddress;
        challengeRewardsAddress = _address;
        emit AddressUpdated("CHALLENGE_REWARDS", oldAddress, _address);
    }

    function setWinRewardsAddress(address _address) external {
        if(winRewardsAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = winRewardsAddress;
        winRewardsAddress = _address;
        emit AddressUpdated("WIN_REWARDS", oldAddress, _address);
    }

    function setRewardsPvPAddress(address _address) external {
        if(rewardsPvPAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = rewardsPvPAddress;
        rewardsPvPAddress = _address;
        emit AddressUpdated("REWARD_PVP", oldAddress, _address);
    }

    // PvP game won't be available before at less 6 months from initial deployment.
    // We lock during 6 months the PvPAddress initiation
    function setPvPAddress(address _address) external {
        require(block.timestamp >= deploymentTimestamp + 183 days, "Only 6 months after TGE");
        if(pvPAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = pvPAddress;
        pvPAddress = _address;
        emit AddressUpdated("PVP", oldAddress, _address);
    }

    function setOpenAndCloseAddress(address _address) external {
        if(openAndCloseAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = openAndCloseAddress;
        openAndCloseAddress = _address;
        emit AddressUpdated("OPEN_AND_CLOSE", oldAddress, _address);
    }

    function setAlchemyAddress(address _address) external {
        if(alchemyAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = alchemyAddress;
        alchemyAddress = _address;
        emit AddressUpdated("ALCHEMY", oldAddress, _address);
    }

    function setLevelStorageAddress(address _address) external {
        if(levelStorageAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = levelStorageAddress;
        levelStorageAddress = _address;
        emit AddressUpdated("LEVEL_STORAGE", oldAddress, _address);
    }

    function setRankingAddress(address _address) external {
        if(rankingContractAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = rankingContractAddress;
        rankingContractAddress = _address;
        emit AddressUpdated("RANKING", oldAddress, _address);
    }

    function setDelegateZaiAddress(address _address) external {
        if(delegateZaiAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = delegateZaiAddress;
        delegateZaiAddress = _address;
        emit AddressUpdated("DELEGATION", oldAddress, _address);
    }

    function setLootAddress(address _address) external {
        if(lootAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = lootAddress;
        lootAddress = _address;
        emit AddressUpdated("LOOT", oldAddress, _address);
    }

    function setClaimNFTsAddress(address _address) external {
        if(claimNFTsAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = claimNFTsAddress;
        claimNFTsAddress = _address;
        emit AddressUpdated("CLAIM_NFT", oldAddress, _address);
    }

    function setMarketPlaceAddress(address _address) external {
        if(marketPlaceAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = marketPlaceAddress;
        marketPlaceAddress = _address;
        emit AddressUpdated("MARKET_PLACE", oldAddress, _address);
    }

    function setRentMyNftAddress(address _address) external onlyOwner {
        if(rentMyNFTAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = rentMyNFTAddress;
        rentMyNFTAddress = _address;
        emit AddressUpdated("RENT_MY_NFT", oldAddress, _address);
    }

    function setChickenAddress(address _address) external {
        if(chickenAddress == address(0)){
             _isOwner();
        }else{
            _isMasterUpdater();
        }
        address oldAddress = chickenAddress;
        chickenAddress = _address;
        emit AddressUpdated("CHICKEN", oldAddress, _address);
    }

//===================================================================================
//===================================================================================
//===================================================================================
//===================================================================================

    function getBZAIAddress() external view returns (address) {
        return BZAITokenAddress;
    }

    function getOracleAddress() external view returns (address) {
        return oracleAddress;
    }

    function getZaiAddress() external view returns (address) {
        return zaiNFTAddress;
    }

    function getZaiMetaAddress() external view returns (address) {
        return zaiMetaAddress;
    }

    function getIpfsStorageAddress() external view returns (address) {
        return ipfsIdStorageAddress;
    }

    function getLaboratoryAddress() external view returns (address) {
        return laboratoryAddress;
    }

    function getLaboratoryNFTAddress() external view returns (address) {
        return laboratoryNFTAddress;
    }

    function getTrainingCenterAddress() external view returns (address) {
        return trainingAddress;
    }

    function getTrainingNFTAddress() external view returns (address) {
        return trainingNFTAddress;
    }

    function getNurseryNFTAddress() external view returns (address) {
        return nurseryNFTAddress;
    }

    function getNurseryManagementAddress() external view returns (address) {
        return nurseryManagementAddress;
    }

    function getPotionAddress() external view returns (address) {
        return potionAddress;
    }

    function getFightAddress() external view returns (address) {
        return fightAddress;
    }

    function getEggsAddress() external view returns (address) {
        return eggsAddress;
    }

    function getMarketZaiAddress() external view returns (address) {
        return marketZaiAddress;
    }

    function getPaymentsAddress() external view returns (address) {
        return paymentsAddress;
    }

    function getChallengeRewardsAddress() external view returns (address) {
        return challengeRewardsAddress;
    }

    function getWinRewardsAddress() external view returns (address) {
        return winRewardsAddress;
    }

    function getRewardsPvPAddress() external view returns (address) {
        return rewardsPvPAddress;
    }

    function getPvPAddress() external view returns (address) {
        return pvPAddress;
    }

    function getOpenAndCloseAddress() external view returns (address) {
        return openAndCloseAddress;
    }

    function getAlchemyAddress() external view returns (address) {
        return alchemyAddress;
    }

    function getLevelStorageAddress() external view returns (address) {
        return levelStorageAddress;
    }

    function getRankingContract() external view returns (address) {
        return rankingContractAddress;
    }

    function getDelegateZaiAddress() external view returns (address) {
        return delegateZaiAddress;
    }

    function getLootAddress() external view returns (address) {
        return lootAddress;
    }

    function getClaimNFTsAddress() external view returns (address) {
        return claimNFTsAddress;
    }

    function getMarketPlaceAddress() external view returns (address) {
        return marketPlaceAddress;
    }

    function getRentMyNftAddress() external view returns (address) {
        return rentMyNFTAddress;
    }

    function getChickenAddress() external view returns (address) {
        return chickenAddress;
    }

    function isAuthToManagedNFTs(address _address)
        external
        view
        returns (bool)
    {
        return (_address == nurseryManagementAddress ||
            _address == trainingAddress ||
            _address == laboratoryAddress ||
            _address == eggsAddress ||
            _address == marketZaiAddress ||
            _address == alchemyAddress ||
            _address == fightAddress ||
            _address == lootAddress);
    }

    function isAuthToManagedPayments(address _address)
        external
        view
        returns (bool)
    {
        return (_address == laboratoryAddress ||
            _address == marketZaiAddress ||
            _address == nurseryManagementAddress ||
            _address == trainingAddress ||
            _address == fightAddress ||
            _address == rankingContractAddress ||
            _address == marketPlaceAddress ||
            _address == potionAddress);
    }

    // UPDATE AUDIT : function allowing update of all interfaces/addresses of protocole contract  
    // This function is called after deployment for finalizing setting of protocole
    // This function is automaticly called by MasterUpdater when an address is updated 
    function updateAllInterfaces() external {
        IZaiMeta(zaiMetaAddress).updateInterfaces();
        IipfsIdStorage(ipfsIdStorageAddress).updateInterfaces();
        ILaboratory(laboratoryNFTAddress).updateInterfaces();
        ILabManagement(laboratoryAddress).updateInterfaces();
        ITraining(trainingNFTAddress).updateInterfaces();
        ITrainingManagement(trainingAddress).updateInterfaces();
        INurseryManagement(nurseryManagementAddress).updateInterfaces();
        IPotions(potionAddress).updateInterfaces();
        IOpenAndClose(openAndCloseAddress).updateInterfaces();
        IFighting(fightAddress).updateInterfaces();
        ILevelStorage(levelStorageAddress).updateInterfaces();
        IRewardsWinningFound(winRewardsAddress).updateInterfaces();
        IRewardsRankingFound(challengeRewardsAddress).updateInterfaces();
        IRewardsPvP(rewardsPvPAddress).updateInterfaces();
        IRanking(rankingContractAddress).updateInterfaces();
        IDelegate(delegateZaiAddress).updateInterfaces();
        ILootProgress(lootAddress).updateInterfaces();
        IMarket(marketZaiAddress).updateInterfaces();
    }
}
