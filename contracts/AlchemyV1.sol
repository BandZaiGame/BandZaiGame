// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces.sol";

// contract for mixing potion when Zai got enough mana
contract AlchemyV1 is Ownable {
    IAddresses public gameAddresses;
    IDelegate public Del;
    IZaiMeta public Zai;
    IPotions public Potions;
    IChicken public Chicken;
    IOracle public Oracle;

    // UPDATE AUDIT : events added
    event GameAddressesSetted(address gameAddresses);
    event InterfacesUpdated(
        address delegateAddress,
        address zaiAddress,
        address potionsAddress,
        address chickenAddress,
        address oracleAddress
    );
    event MultiplePotionMinted(
        address indexed owner,
        uint256 wizardId,
        uint256 potionId
    );

    modifier canUseZai(uint256 _zaiId) {
        require(
            Del.canUseZai(_zaiId, msg.sender),
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

    // UPDATE AUDIT : update interfaces/address
    function updateInterfaces() external {
        Del = IDelegate(
            gameAddresses.getAddressOf(AddressesInit.Addresses.DELEGATE)
        );
        Zai = IZaiMeta(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ZAI_META)
        );
        Potions = IPotions(
            gameAddresses.getAddressOf(AddressesInit.Addresses.POTIONS_NFT)
        );
        Chicken = IChicken(
            gameAddresses.getAddressOf(AddressesInit.Addresses.CHICKEN)
        );
        Oracle = IOracle(
            gameAddresses.getAddressOf(AddressesInit.Addresses.ORACLE)
        );
        emit InterfacesUpdated(
            address(Del),
            address(Zai),
            address(Potions),
            address(Chicken),
            address(Oracle)
        );
    }

    // use to add mana in mana recipient of Zai
    function usePotionMana(uint256 _zaiId, uint256 _potionId)
        external
        canUseZai(_zaiId)
    {
        require(Potions.ownerOf(_potionId) == msg.sender, "not your Potion");
        Potions.burnPotion(_potionId);

        PotionStruct.Potion memory p = Potions.getFullPotion(_potionId);
        require(p.powers.mana != 0, "not a mana potion");
        Zai.updateMana(_zaiId, p.powers.mana, 0, 0);
    }

    //rules:
    // minimum 2 potions ::: maximum 6 potions
    // manaused = nbOfPotion * 1000 => ex: 4000 mana for 4 potions
    // Zai must have :
    // - 10000 manaMax for mixing 6 potions
    // - 8000 manaMax for mixing 5 potions
    // - 6000 manaMax for mixing 4 potions
    // - 4000 manaMax for mixing 3 potions
    // - 2000 manaMax for mixing 2 potions
    // When Zai use this function, he increasehis manaMax jauge by 50 (manaMax can't be higher than 10k)
    // manaAdditionnal can be 0, but there won't be additionnal pts in the new potion
    // there is a bonus of 1pt for each 1k manaAdditionnal put in the alchemy
    // if the Zai alchemist is level 10 , 1K manaAdditionnal give 2 bonus pts (3 for level 20, 4 for level 30 ...)
    function useAlchemy(
        uint256 _zaiId,
        uint256[] memory _usedPotions,
        uint256 _manaUsed,
        uint256 _manaAdditional,
        bool _isManaMix
    ) external canUseZai(_zaiId) returns (uint256 potionId) {
        // UPDATE AUDIT : prevent bot action
        require(tx.origin == msg.sender, "contract not allowed");
        require(_usedPotions.length >= 2, "Minimum 2 potions");
        require(_usedPotions.length <= 6, "Maximum 6 potions");
        require(
            _manaUsed >= _usedPotions.length * 1000,
            "Need to use 1000 mana per potion"
        );
        require(
            _manaAdditional % 1000 == 0 || _manaAdditional == 0,
            "Must use 1000 multiple for _manaAdditionnal"
        );

        ZaiStruct.Zai memory z = Zai.getZai(_zaiId);

        if (_usedPotions.length == 6) {
            require(z.manaMax == 10000, "Not enough manaMax");
        } else if (_usedPotions.length == 5) {
            require(z.manaMax >= 8000, "Not enough manaMax");
        } else if (_usedPotions.length == 4) {
            require(z.manaMax >= 6000, "Not enough manaMax");
        } else if (_usedPotions.length == 3) {
            require(z.manaMax >= 4000, "Not enough manaMax");
        } else if (_usedPotions.length == 2) {
            require(z.manaMax >= 2000, "Not enough manaMax");
        }

        // reduce mana from zai's mana recipient + add 50 to manaMax
        require(Zai.updateMana(_zaiId, 0, (_manaUsed + _manaAdditional), 10));

        uint256[7] memory _powers;

        // add all potions powers tohether
        for (uint256 i; i < _usedPotions.length; ) {
            PotionStruct.Potion memory p = Potions.getFullPotion(
                _usedPotions[i]
            );
            require(
                Potions.ownerOf(_usedPotions[i]) == msg.sender,
                "Not your potion"
            );
            require(p.powers.rest == 0, "Impossible to mix rest potions");
            require(Potions.burnPotion(_usedPotions[i]));
            if (!_isManaMix) {
                if (p.powers.water != 0) {
                    _powers[0] += p.powers.water;
                }
                if (p.powers.fire != 0) {
                    _powers[1] += p.powers.fire;
                }
                if (p.powers.metal != 0) {
                    _powers[2] += p.powers.metal;
                }
                if (p.powers.air != 0) {
                    _powers[3] += p.powers.air;
                }
                if (p.powers.stone != 0) {
                    _powers[4] += p.powers.stone;
                }
                if (p.powers.xp != 0) {
                    _powers[5] += p.powers.xp;
                }
            } else {
                _powers[6] += p.powers.mana;
            }
            unchecked {
                ++i;
            }
        }

        // when manaAdditional, get some add points
        if (_manaAdditional > 1000) {
            // each ten levels of zai make a bigger multiplier (level 10 give multiplier 2, level 20 : multiplier 3 ...)
            uint256 _additionnalPoints = (_manaAdditional / 1000) *
                ((z.level / 10) + 1);
            if (_isManaMix) {
                // UPDATE AUDIT: fix by deleting "!"
                _powers[6] += _additionnalPoints * 100;
            } else {
                uint256 _random = Oracle.getRandom();
                while (_additionnalPoints != 0) {
                    --_additionnalPoints;
                    ++_powers[_random % 5]; // UPDATE AUDIT: xp can't be add
                    _random /= 10;
                }
            }
        }

        if (!_isManaMix) {
            potionId = Potions.mintMultiplePotion(_powers, msg.sender);
        } else {
            potionId = Potions.offerPotion(8, _powers[6], msg.sender);
        }
        emit MultiplePotionMinted(msg.sender, _zaiId, potionId);

        // 4% chance to mint a magical chicken
        if (Oracle.getRandom() % 100 < 4) {
            Chicken.mintChicken(msg.sender);
        }

        return potionId;
    }
}
