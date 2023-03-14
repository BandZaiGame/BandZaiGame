// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Contract for claiming BZAI from private / public sale and Advisors
// each participant will have a NFT representing their allocation
// NFT can be sold on 2nd market and is necessary to claim BZAI
// UPDATE AUDIT :  Delete public vesting => No IDO
contract ClaimBzai is Ownable, ERC721Enumerable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    IERC20 public BZAI;

    // amount assigned by owner
    uint256 public assigned;
    // UPDATE AUDIT :  change block.number by block.timestamp
    //uint256 constant _blockEvery = 2; // block every 2 seconds on polygon mainnet

    struct VestingNFT {
        string vestingType;
        uint256 initialAmount;
        uint256 claimedAmount;
    }

    mapping(uint256 => VestingNFT) _vestingNFT;

    event Claimed(
        address indexed user,
        uint256 indexed nftId,
        string vestingType,
        uint256 amount
    );
    event NFTReset(
        address indexed user,
        uint256 indexed nftId,
        string vestingType,
        uint256 amount
    );
    event TgeSetted(uint256 TgeTimestamp);
    event AllocSetted(address indexed user, string vestingType, uint256 amount);
    event UnassignedWithdrawed(uint256 amount);

    uint256 public tgeUnlockedTimestamp;

    mapping(uint256 => uint256[7]) _privateVestingAmount;
    mapping(uint256 => uint256[6]) _advisorsVestingAmount;

    uint256[7] _privateVestingTimestamp;
    uint256[6] _advisorsVestingTimestamp;

    constructor(address _BZAI) ERC721("Claim_BZAI_Vesting", "CLAIM") {
        BZAI = IERC20(_BZAI);
    }

    function getNftDatas(uint256 _tokenId)
        external
        view
        returns (VestingNFT memory)
    {
        return _vestingNFT[_tokenId];
    }

    // UPDATE AUDIT : get all vesting timestamp
    function getVestingTimestamp()
        external
        view
        returns (
            uint256[7] memory privateVestingTimestamp,
            uint256[6] memory advisorVestingTimestamp
        )
    {
        return (_privateVestingTimestamp, _advisorsVestingTimestamp);
    }

    function setTgeTimestamp(uint256 _timestamp) external onlyOwner {
        require(
            tgeUnlockedTimestamp == 0 || tgeUnlockedTimestamp > block.timestamp,
            "Can't set after TGE started"
        );
        require(_timestamp > block.timestamp, "TGE can't be in past time");

        tgeUnlockedTimestamp = _timestamp;
        uint256 toAdd = 86400 * 30; // 86400 seconds by day * 30(days)

        // private TGE setting
        _privateVestingTimestamp[0] = _timestamp + (86400 * 15); // first batch at TGE + 15 days

        // advisor distribution start 30 days after TGE
        _advisorsVestingTimestamp[0] = _timestamp + toAdd;

        // initiates timestamps claimable
        for (uint256 i = 1; i < 6; ) {
            _privateVestingTimestamp[i] = _timestamp + (i * toAdd);
            _advisorsVestingTimestamp[i] =
                _advisorsVestingTimestamp[0] +
                (i * toAdd);
            unchecked {
                ++i;
            }
        }

        // last private claimable timestamp
        _privateVestingTimestamp[6] = _timestamp + (6 * toAdd);

        emit TgeSetted(_timestamp);
    }

    // before TGE owner can change distribution of an NFT
    function resetNFT(uint256 tokenId) external onlyOwner {
        require(
            block.timestamp <= tgeUnlockedTimestamp ||
                tgeUnlockedTimestamp == 0,
            "too late to change anything"
        );
        address _owner = ownerOf(tokenId);
        string memory _vestingType = _vestingNFT[tokenId].vestingType;
        uint256 _amount = _vestingNFT[tokenId].initialAmount;
        delete _vestingNFT[tokenId];
        _privateVestingAmount[tokenId] = [0, 0, 0, 0, 0, 0, 0];
        _advisorsVestingAmount[tokenId] = [0, 0, 0, 0, 0, 0];

        assigned -= _amount;
        _burn(tokenId);

        emit NFTReset(_owner, tokenId, _vestingType, _amount);
    }

    function _mintNFT(address _user) internal returns (uint256) {
        _tokenIds.increment();
        uint256 _newItemId = _tokenIds.current();
        _safeMint(_user, _newItemId);
        return _newItemId;
    }

    function setAdvisorsVesting(address _user, uint256 _amount)
        external
        onlyOwner
    {
        require(
            BZAI.balanceOf(address(this)) >= assigned + _amount,
            "To much assigned"
        );
        //update assignation tokens (debt)
        assigned += _amount;

        // mint claim NFT
        uint256 nftId = _mintNFT(_user);
        _vestingNFT[nftId] = VestingNFT("advisor", _amount, 0);
        uint256 claimablePart = _amount / 6;
        // calculate rest of division to avoid decimals not distributed
        uint256 modulo = _amount % 6;

        _advisorsVestingAmount[nftId][0] = claimablePart;
        _advisorsVestingAmount[nftId][1] = claimablePart;
        _advisorsVestingAmount[nftId][2] = claimablePart;
        _advisorsVestingAmount[nftId][3] = claimablePart;
        _advisorsVestingAmount[nftId][4] = claimablePart;
        _advisorsVestingAmount[nftId][5] = claimablePart + modulo;

        emit AllocSetted(_user, "advisor", _amount);
    }

    function setPrivateVesting(address _user, uint256 _amount)
        external
        onlyOwner
    {
        require(
            BZAI.balanceOf(address(this)) >= assigned + _amount,
            "To much assigned"
        );
        assigned += _amount;

        uint256 nftId = _mintNFT(_user);
        _vestingNFT[nftId] = VestingNFT("private", _amount, 0);
        uint256 firstClaimable = _amount / 10; // 10% at tge
        _privateVestingAmount[nftId][0] = firstClaimable;
        uint256 claimablePart = (_amount * 15) / 100;
        uint256 modulo = _amount - firstClaimable - (claimablePart * 6);

        _privateVestingAmount[nftId][0] = firstClaimable;
        _privateVestingAmount[nftId][1] = claimablePart;
        _privateVestingAmount[nftId][2] = claimablePart;
        _privateVestingAmount[nftId][3] = claimablePart;
        _privateVestingAmount[nftId][4] = claimablePart;
        _privateVestingAmount[nftId][5] = claimablePart;
        _privateVestingAmount[nftId][6] = claimablePart + modulo;

        emit AllocSetted(_user, "private", _amount);
    }

    function getClaimable(address _user) external view returns (uint256) {
        return _getClaimable(_user);
    }

    function _getClaimable(address _user) internal view returns (uint256) {
        uint256 balance = balanceOf(_user);
        if (balance == 0) {
            return 0;
        } else {
            uint256 claimable;
            for (uint256 i; i < balance; ) {
                uint256 tokenId = tokenOfOwnerByIndex(_user, i);
                if (
                    keccak256(
                        abi.encodePacked(_vestingNFT[tokenId].vestingType)
                    ) == keccak256(abi.encodePacked("private"))
                ) {
                    claimable += _getPrivateClaimable(tokenId);
                } else if (
                    keccak256(
                        abi.encodePacked(_vestingNFT[tokenId].vestingType)
                    ) == keccak256(abi.encodePacked("advisor"))
                ) {
                    claimable += _getAdvisorClaimable(tokenId);
                }
                unchecked {
                    ++i;
                }
            }
            return claimable;
        }
    }

    function _getPrivateClaimable(uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        uint256 _claimable;
        for (uint256 i; i < 7; ) {
            if (block.timestamp >= _privateVestingTimestamp[i]) {
                _claimable += _privateVestingAmount[tokenId][i];
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }
        return _claimable;
    }

    function _getAdvisorClaimable(uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        uint256 _claimable;
        for (uint256 i; i < 6; ) {
            if (block.timestamp >= _advisorsVestingTimestamp[i]) {
                _claimable += _advisorsVestingAmount[tokenId][i];
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }
        return _claimable;
    }

    function _cleanClaimable(address _user) internal returns (uint256) {
        uint256 balance = balanceOf(_user);
        if (balance == 0) {
            return 0;
        } else {
            uint256 cleaned;
            for (uint256 i; i < balance; ) {
                uint256 tokenId = tokenOfOwnerByIndex(_user, i);
                if (
                    keccak256(
                        abi.encodePacked(_vestingNFT[tokenId].vestingType)
                    ) == keccak256(abi.encodePacked("private"))
                ) {
                    cleaned += _cleanPrivateClaimable(tokenId, _user);
                } else if (
                    keccak256(
                        abi.encodePacked(_vestingNFT[tokenId].vestingType)
                    ) == keccak256(abi.encodePacked("advisor"))
                ) {
                    cleaned += _cleanAdvisorClaimable(tokenId, _user);
                }
                unchecked {
                    ++i;
                }
            }
            return cleaned;
        }
    }

    function _cleanPrivateClaimable(uint256 tokenId, address user)
        internal
        returns (uint256)
    {
        uint256 _cleaned;
        for (uint256 i; i < 7; ) {
            if (block.timestamp >= _privateVestingTimestamp[i]) {
                _cleaned += _privateVestingAmount[tokenId][i];
                _vestingNFT[tokenId].claimedAmount += _privateVestingAmount[
                    tokenId
                ][i];
                _privateVestingAmount[tokenId][i] = 0;
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit Claimed(user, tokenId, "private", _cleaned);

        return _cleaned;
    }

    function _cleanAdvisorClaimable(uint256 tokenId, address user)
        internal
        returns (uint256)
    {
        uint256 _cleaned;
        for (uint256 i; i < 6; ) {
            if (block.timestamp >= _advisorsVestingTimestamp[i]) {
                _cleaned += _advisorsVestingAmount[tokenId][i];
                _vestingNFT[tokenId].claimedAmount += _advisorsVestingAmount[
                    tokenId
                ][i];
                _advisorsVestingAmount[tokenId][i] = 0;
            } else {
                break;
            }
            unchecked {
                ++i;
            }
        }
        emit Claimed(user, tokenId, "advisor", _cleaned);

        return _cleaned;
    }

    function claimBZAIs() external nonReentrant {
        // can't claim before TGE
        require(tgeUnlockedTimestamp != 0, "tge not set");
        require(block.timestamp >= tgeUnlockedTimestamp, "Too soon !");

        uint256 _claimable = _getClaimable(msg.sender);
        uint256 _cleaned = _cleanClaimable(msg.sender);
        // check claimable is ok
        require(_claimable == _cleaned, "Something wrong in claimable process");
        // update assigned
        assigned -= _cleaned;

        require(BZAI.transfer(msg.sender, _cleaned));
        // check
        require(assigned <= BZAI.balanceOf(address(this)));
    }

    // allow owner to withdra excedent of token non assigned
    function withdrawUnassigned() external onlyOwner {
        // UPDATE AUDIT : forgot BZAI. for balanceOf => BZAI could be lost
        uint256 _amount = BZAI.balanceOf(address(this)) - assigned;
        require(BZAI.transfer(msg.sender, _amount));
        emit UnassignedWithdrawed(_amount);
    }
}
