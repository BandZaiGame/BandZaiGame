// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces.sol";

// Main NFT zai/card contract

contract BandZaiView is Ownable {
    // IAddresses public gameAddresses;

    // string[4] eggOrZaitype = ["bronze", "silver", "gold", "platinum"];

    // function setGameAddresses(address _address) external onlyOwner {
    //     gameAddresses = IAddresses(_address);
    // }

    // function getNextEggDatas(uint256 _nursId)
    //     external
    //     view
    //     returns (
    //         uint256 idEgg,
    //         string memory eggType,
    //         string memory nursName,
    //         uint256 avalaibleAt,
    //         uint256 price
    //     )
    // {
    //     INurseryManagement InursMan = INurseryManagement(gameAddresses.getNurseryManagementAddress());
    //     uint256 _type = InursMan.nextStateToMint(_nursId);
    //     ZaiStruct.EggsPrices memory _prices = InursMan.getEggsPrices(_nursId);

    //     ZaiStruct.MintedData memory _mintedDatas = InursMan.getNurseryMintedDatas(
    //         _nursId
    //     );

    //     uint256 _idEgg = _mintedDatas.bronzeMinted +
    //         _mintedDatas.silverMinted +
    //         _mintedDatas.goldMinted +
    //         _mintedDatas.platinumMinted +
    //         1;

    //     return (
    //         _idEgg,
    //         eggOrZaitype[_type],
    //         IOpenAndClose(gameAddresses.getOpenAndCloseAddress())
    //             .getNurseryName(_nursId),
    //         InursMan.getNextUnlock(_nursId),
    //         _type == 0 ? _prices.bronzePrice : _type == 1
    //             ? _prices.silverPrice
    //             : _type == 2
    //             ? _prices.goldPrice
    //             : _prices.platinumPrice
    //     );
    // }

    // struct FullZai {
    //     ZaiStruct.Zai zai;
    //     address owner;
    //     uint256 stamina;
    //     uint256 numberOfWinThisDay;
    //     uint256 lastTrain;
    //     uint256 currentLevelUpPoint;
    //     uint256 nextLevelUpPoint;
    //     ZaiStruct.DelegateData delegationData;
    // }

    // function getFullZai(uint256 _tokenId)
    //     external
    //     view
    //     returns (FullZai memory)
    // {
    //     FullZai memory z;
    //     IZaiNFT INFT = IZaiNFT(gameAddresses.getZaiAddress());
    //     IZaiMeta IMeta = IZaiMeta(gameAddresses.getZaiMetaAddress());
    //     z.zai = IMeta.getZai(_tokenId);
    //     z.owner = INFT.ownerOf(_tokenId);
    //     z.currentLevelUpPoint = IMeta.getNextLevelUpPoints(z.zai.level);
    //     z.nextLevelUpPoint = IMeta.getNextLevelUpPoints(z.zai.level + 1);
    //     IFighting IFight = IFighting(gameAddresses.getFightAddress());
    //     z.stamina = IFight.getZaiStamina(_tokenId);
    //     z.lastTrain = ITrainingManagement(
    //         gameAddresses.getTrainingCenterAddress()
    //     ).getZaiLastTrainBegining(_tokenId);
    //     z.numberOfWinThisDay = IFight.getDayWinByZai(_tokenId);
    //     z.delegationData = IDelegate(gameAddresses.getDelegateZaiAddress())
    //         .getDelegateDatasByZai(_tokenId);

    //     return z;
    // }

    // struct LaboDatas {
    //     uint256 labId;
    //     string name;
    //     uint256 labItems;
    //     uint256 credit;
    //     uint256 revenues;
    //     string labStatus;
    // }

    // function getMyLabs(address _address)
    //     external
    //     view
    //     returns (LaboDatas[] memory)
    // {
    //     ILaboratory LabNFT = ILaboratory(
    //         gameAddresses.getLaboratoryNFTAddress()
    //     );
    //     ILabManagement LabManagement = ILabManagement(
    //         gameAddresses.getLaboratoryAddress()
    //     );
    //     IOpenAndClose openAndClose = IOpenAndClose(
    //         gameAddresses.getOpenAndCloseAddress()
    //     );

    //     uint256 myLabBalance = LabNFT.balanceOf(_address);
    //     LaboDatas[] memory myLabList = new LaboDatas[](myLabBalance);

    //     if (myLabBalance > 0) {
    //         for (uint256 i = 0; i < myLabBalance; i++) {
    //             LaboDatas memory L;
    //             L.labId = LabNFT.tokenOfOwnerByIndex(_address, i);
    //             L.name = openAndClose.getLaboratoryName(L.labId);
    //             L.labItems = LabManagement.createdPotionsForLab(L.labId);
    //             L.credit = LabManagement.getCredit(L.labId);
    //             L.revenues = LabManagement.laboratoryRevenues(L.labId);
    //             L.labStatus = openAndClose.getLaboratoryState(L.labId);

    //             myLabList[i] = L;
    //         }
    //     }
    //     return myLabList;
    // }

    // struct LabSlot {
    //     string labName;
    //     uint256 idSlotLab;
    //     uint256 idWorker;
    //     uint256 workerStartDate;
    // }

    // function getLabSlots(uint256 _labId)
    //     external
    //     view
    //     returns (LabSlot[] memory)
    // {
    //     ILaboratory LabNFT = ILaboratory(
    //         gameAddresses.getLaboratoryNFTAddress()
    //     );
    //     ILabManagement LabManagement = ILabManagement(
    //         gameAddresses.getLaboratoryAddress()
    //     );

    //     uint256 slotsNumbers = LabNFT.numberOfWorkingSpots(_labId);
    //     IOpenAndClose openAndClose = IOpenAndClose(
    //         gameAddresses.getOpenAndCloseAddress()
    //     );

    //     LabSlot[] memory labSlots = new LabSlot[](slotsNumbers);

    //     for (uint256 i = 1; i <= slotsNumbers; i++) {
    //         ZaiStruct.WorkInstance memory W = LabManagement.workingSpot(
    //             _labId,
    //             i
    //         );
    //         LabSlot memory L;
    //         L.labName = openAndClose.getLaboratoryName(_labId);
    //         L.idSlotLab = i;
    //         L.idWorker = W.zaiId;
    //         L.workerStartDate = W.beginingAt;

    //         labSlots[i - 1] = L;
    //     }

    //     return labSlots;
    // }

    // struct Nursery {
    //     uint256 nursId;
    //     string nursName;
    //     string nursStatus;
    //     uint256 nursProfits;
    //     uint256 nextStatusToMint;
    //     uint256 nextUnlock;
    //     ZaiStruct.MintedData mintedDatas;
    //     ZaiStruct.EggsPrices eggsPrices;
    // }

    // function getMyNurseries(address _address)
    //     external
    //     view
    //     returns (Nursery[] memory)
    // {
    //     INurseryNFT INurs = INurseryNFT(gameAddresses.getNurseryNFTAddress());
    //     uint256 balance = INurs.balanceOf(_address);
    //     Nursery[] memory nurseries = new Nursery[](balance);
    //     for (uint256 i = 0; i < balance; i++) {
    //         uint256 tokenId = INurs.tokenOfOwnerByIndex(_address, i);
    //         nurseries[i] = _getNurseryById(tokenId);
    //     }
    //     return nurseries;
    // }

    // function _getNurseryById(uint256 _tokenId)
    //     internal
    //     view
    //     returns (Nursery memory)
    // {
    //     Nursery memory n;
    //     IOpenAndClose IOpen = IOpenAndClose(
    //         gameAddresses.getOpenAndCloseAddress()
    //     );
    //     INurseryManagement InursMan = INurseryManagement(gameAddresses.getNurseryManagementAddress());
    //     //INurseryNFT INurs = INurseryNFT(gameAddresses.getNurseryNFTAddress());
    //     n.nursId = _tokenId;
    //     n.nursName = IOpen.getNurseryName(_tokenId);
    //     n.nursStatus = "open";
    //     n.nursProfits = InursMan.nurseryRevenues(_tokenId);
    //     n.mintedDatas = InursMan.nurseryMintedDatas(_tokenId);
    //     n.nextStatusToMint = InursMan.nextStateToMint(_tokenId);
    //     n.nextUnlock = InursMan.getNextUnlock(_tokenId);
    //     n.eggsPrices = InursMan.getEggsPrices(_tokenId);

    //     return n;
    // }

    // function getNumberOfPotionsSalePages() external view returns (uint256) {
    //     IPotions potionContract = IPotions(gameAddresses.getPotionAddress());
    //     address laboManagementAddress = gameAddresses.getLaboratoryAddress();
    //     uint256 balance = potionContract.balanceOf(laboManagementAddress);
    //     if (balance == 0) {
    //         return balance;
    //     } else {
    //         return ((balance / 25) + 1);
    //     }
    // }

    // function getPotionsInSale(uint256 _page)
    //     external
    //     view
    //     returns (PotionStruct.Potion[] memory)
    // {
    //     IPotions potionContract = IPotions(gameAddresses.getPotionAddress());
    //     address laboManagementAddress = gameAddresses.getLaboratoryAddress();
    //     uint256 totalPotions = potionContract.balanceOf(laboManagementAddress); // 40
    //     uint256 startingRange = 0 + ((_page - 1) * 25);
    //     uint256 endOfRange = startingRange + 25;

    //     if (endOfRange > totalPotions) {
    //         endOfRange = totalPotions;
    //     }

    //     PotionStruct.Potion[] memory potions = new PotionStruct.Potion[](
    //         endOfRange - startingRange
    //     );

    //     for (uint256 i = startingRange; i < endOfRange; ) {
    //         uint256 potionId = potionContract.tokenOfOwnerByIndex(
    //             laboManagementAddress,
    //             i
    //         );
    //         PotionStruct.Potion memory p = potionContract.getFullPotion(
    //             potionId
    //         );
    //         potions[i - startingRange] = p;
    //         unchecked {
    //             ++i;
    //         }
    //     }
    //     return potions;
    // }
}
