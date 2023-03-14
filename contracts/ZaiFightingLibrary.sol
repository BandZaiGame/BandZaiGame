// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./Interfaces.sol";

// contract who generate challenger strategy
// UPDATE AUDIT : unchecked math when sure of math
// replace += 1 by ++ , i = 0 by i ,
contract ZaiFightingLibrary {
    // UPDATE AUDIT : replace uint256[9] memory by calldata
    function updateFightingProgress(
        uint256[30] memory _toReturn,
        uint256[9] calldata _elements,
        uint256[9] calldata _powers
    ) external pure returns (uint256[30] memory) {
        for (uint256 i; i < 9; ) {
            unchecked {
                if (_winTheRound(_elements[i], _toReturn[i + 3]) == 1) {
                    _toReturn[1] += _powers[i]; // My score
                } else if (_winTheRound(_elements[i], _toReturn[i + 3]) == 0) {
                    _toReturn[2] += _toReturn[i + 12]; //challenger score
                } else if (_winTheRound(_elements[i], _toReturn[i + 3]) == 2) {
                    // draw round (player who have the more point score the difference between)
                    if (_powers[i] > _toReturn[i + 12]) {
                        _toReturn[1] += (_powers[i] - _toReturn[i + 12]);
                    }
                    if (_toReturn[i + 12] > _powers[i]) {
                        _toReturn[2] += (_toReturn[i + 12] - _powers[i]);
                    }
                }
                ++i;
            }
        }
        return _toReturn;
    }

    // return [water,fire,metal,air,stone,numberOfusedPotions,potionId1,potionId2,potionId3]
    function _getchallengerPowers(
        ZaiStruct.ZaiMinDatasForFight memory c,
        uint256 _random
    ) internal pure returns (uint256[14] memory) {
        // O-4 elements powers , 5 number of potions used , 6-8 potions type, 9-11 potions power, 12 number of elements active, 13 total powers

        uint256[14] memory _result;
        unchecked {
            // for level 0 to 9 we substrate 1 by active element
            _result[0] = c.water != 0
                ? c.level < 10 ? (c.water - 1) : c.water
                : 0;
            _result[1] = c.fire != 0 ? c.level < 10 ? (c.fire - 1) : c.fire : 0;
            _result[2] = c.metal != 0
                ? c.level < 10 ? (c.metal - 1) : c.metal
                : 0;
            _result[3] = c.air != 0 ? c.level < 10 ? (c.air - 1) : c.air : 0;
            _result[4] = c.stone != 0
                ? c.level < 10 ? (c.stone - 1) : c.stone
                : 0;

            //define no potion
            _result[6] = 5;
            _result[7] = 5;
            _result[8] = 5;

            // define number of potion used (no potion when level of fighters < 3)
            // after level 3: 50% of time challenger won't have potions
            if (c.level >= 3 && _random % 2 == 0) {
                // other 50% Zai can have 1 , 2 or 3 potions
                _result[5] = ((_random / 100) % 3) + 1;
            }

            for (uint256 i; i < _result[5]; ) {
                uint256[2] memory _potion; //[type,power]
                _potion[0] = (uint256(_random / (i + 2)) % 5);
                _potion[1] =
                    (uint256(_random / (i + 1)) % ((c.level * 3 + 8) / 8)) +
                    1; // => 1/3 of challenger total power -- ex: if level 10, potion can be 12pts where Challenger has 38 totalPoints

                //Apply potion power to challenger powers
                _result[_potion[0]] += _potion[1];
                //Apply potion to return fight progress
                _result[i + 6] = _potion[0]; //6-8 potions type
                _result[i + 9] = _potion[1]; //9-11 potions power

                ++i;
            }

            //define number of element challenger can use
            for (uint256 i; i < 5; ) {
                if (_result[i] != 0) {
                    // active elements
                    ++_result[12]; //12 number of elements active
                    // total powers
                    _result[13] += _result[i]; //13 total powers
                }
                ++i;
            }
        }
        return _result;
    }

    function getNewPattern(
        uint256 _random,
        ZaiStruct.ZaiMinDatasForFight memory c,
        uint256[30] memory _toReturn
    ) external pure returns (uint256[30] memory result) {
        // O-4 elements powers , 5 number of potions used , 6-8 potions type, 9-11 potions power, 12 number of elements active, 13 total powers
        uint256[14] memory _cPowers = _getchallengerPowers(c, _random);
        _toReturn[21] = _cPowers[5];

        // complete potions used by challenger
        for (uint256 i; i < 3; ) {
            unchecked {
                _toReturn[i + 22] = _cPowers[i + 6];
                _toReturn[i + 25] = _cPowers[i + 9];
                ++i;
            }
        }

        return _getPattern(_cPowers, _random, _toReturn);
    }

    function _getPattern(
        uint256[14] memory _powers,
        uint256 _random,
        uint256[30] memory _toReturn
    ) internal pure returns (uint256[30] memory toReturn) {
        uint256[9] memory elements; // elements pattern for 9 rounds
        uint256[9] memory powers; // powers(points) pattern for 9 rounds
        unchecked {
            uint256[] memory _activePowers = new uint256[](_powers[12]); // power[12] = number of active elements
            uint256 activeIndex;

            // push active elements in _activePowers array
            for (uint256 i; i < 5; ) {
                if (_powers[i] != 0) {
                    _activePowers[activeIndex] = i;
                    ++activeIndex;
                }
                ++i;
            }

            // define elements with each active powers in firsts rounds
            // to be sure that all active elements are played at least one time
            for (uint256 i; i < _powers[12]; ) {
                elements[i] = _activePowers[i];
                ++i;
            }

            // then complete others rounds with randomize elements
            for (uint256 i = _powers[12]; i < 9; ) {
                elements[i] = _activePowers[
                    uint256(_random / (i + 1)) % _powers[12]
                ];
                ++i;
            }

            // define number of point by element for each rounds
            for (uint256 i; i < 3; ) {
                for (uint256 j; j < 9; ) {
                    uint256 power;
                    if (_powers[elements[j]] != 0) {
                        // if challenger has power points in stock in this element
                        power =
                            (uint256(_random / (j + i + 1)) %
                                _powers[elements[j]]) +
                            1; // randomize point quantity ( depending of stock)
                        powers[j] += power; // use points in this round
                        _powers[elements[j]] -= power; // substrate to the element points stock
                        _powers[13] -= power; //substrate point to total points
                        if (_powers[13] == 0) {
                            break;
                        }
                    }
                    ++j;
                }
                if (_powers[13] == 0) {
                    break;
                }
                ++i;
            }

            // finalize the remaining distribution points
            for (uint256 i; i < 9; ) {
                if (powers[i] == 0 && _powers[elements[i]] == 0) {
                    // if no points atributed in this round and no stock left in this element
                    elements[i] = 5; // no element play in this round
                } else {
                    powers[i] += _powers[elements[i]]; // else we add the remaining points of element stock
                    _powers[13] -= _powers[elements[i]]; // substrate from total powers
                    _powers[elements[i]] = 0; // apply 0 to stock
                }
                ++i;
            }

            // get a random order like [8,5,3,7,6,1,2,4,0]
            // allows a true random distribution of challenger powers. (ex : not only big hit at begining of fight)
            uint8[9] memory randomOrder = _getRandomOrder(_random);

            //3-11: ElementByRoundOfChallenger, 12-20: PowerUseByChallengerByRound
            for (uint256 i; i < 9; ) {
                _toReturn[i + 3] = elements[randomOrder[i]];
                _toReturn[i + 12] = powers[randomOrder[i]];
                ++i;
            }
        }
        return _toReturn;
    }

    function _getRandomOrder(uint256 _randoms)
        internal
        pure
        returns (uint8[9] memory)
    {
        uint8[9] memory randomOrder = [0, 1, 2, 3, 4, 5, 6, 7, 8];
        for (uint256 r = 8; r != 0; ) {
            unchecked {
                uint256 randomIndex = uint256(_randoms / (r + 2)) % 9;
                uint8 _temp = randomOrder[r];
                randomOrder[r] = randomOrder[randomIndex];
                randomOrder[randomIndex] = _temp;
                --r;
            }
        }
        return randomOrder;
    }

    function _winTheRound(uint256 _myHit, uint256 _challengerHit)
        internal
        pure
        returns (uint256)
    {
        uint256 _result;
        if (
            (_myHit == 0 && _challengerHit == 1) ||
            (_myHit == 0 && _challengerHit == 2)
        ) {
            _result = 1;
        } else if (
            (_myHit == 1 && _challengerHit == 2) ||
            (_myHit == 1 && _challengerHit == 3)
        ) {
            _result = 1;
        } else if (
            (_myHit == 2 && _challengerHit == 3) ||
            (_myHit == 2 && _challengerHit == 4)
        ) {
            _result = 1;
        } else if (
            (_myHit == 3 && _challengerHit == 4) ||
            (_myHit == 3 && _challengerHit == 0)
        ) {
            _result = 1;
        } else if (
            (_myHit == 4 && _challengerHit == 0) ||
            (_myHit == 4 && _challengerHit == 1)
        ) {
            _result = 1;
        } else if (_myHit != 5 && _challengerHit == 5) {
            _result = 1;
        } else if (_myHit == _challengerHit) {
            _result = 2;
        } else {
            _result = 0;
        }
        return _result;
    }

    function isPowersUsedCorrect(
        uint8[5] calldata _got,
        uint256[5] calldata _used
    ) external pure returns (bool) {
        return (_got[0] >= _used[0] &&
            _got[1] >= _used[1] &&
            _got[2] >= _used[2] &&
            _got[3] >= _used[3] &&
            _got[4] >= _used[4]);
    }

    function getUsedPowersByElement(
        uint256[9] calldata _elements,
        uint256[9] calldata _powers
    ) external pure returns (uint256[5] memory) {
        uint256[5] memory usedPowers;
        for (uint256 i; i < 9; ) {
            require(_elements[i] <= 5, "Element !valid"); // 5 is non element
            unchecked {
                if (_powers[i] == 0) {
                    require(_elements[i] == 5, "Cheat!");
                }
                if (_powers[i] != 0 && _elements[i] != 5) {
                    usedPowers[_elements[i]] += _powers[i];
                }
                ++i;
            }
        }
        return usedPowers;
    }
}
