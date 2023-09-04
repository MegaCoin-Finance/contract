// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./Address.sol";
import "./Context.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./IMegaJackpot.sol";
import "./ReentrancyGuard.sol";

contract MegaJackpot is IMegaJackpot, ReentrancyGuard, Ownable {
    using Address for address;
    using SafeMath for uint256;

    event PlayGame(address contractGame, uint256 idGame, uint256 qty);

    string private _name = "Mega Jackpot V1";
    uint256 constant public PERCENTS_DIVIDER = 1000;
    uint256 constant public SPIN_PERCENTS_DIVIDER = 1000_000_000;
    IERC20 public token;
    uint256 public indexGame = 0;
    uint256 public nonce = 0;
    address public ownerWallet;

    struct Prize {
        uint256 value;
        uint256 percent;
    }
    struct RewardSpin {
        bool jackpot;
        uint256 qty;
        uint256 tokenId;
    }
    struct Game {
        uint256 price;
        uint256 startPrize;
        string title;
        uint256 ownerPercent;
        uint256 affiliatePercent;
        uint256 term;
        uint256 totalReward;
        uint256 totalSpin;
    }

    mapping(uint256 => Game) public gameInfo;
    mapping(uint256 => mapping(uint256 => Prize)) public prize;
    mapping(bytes32 => mapping(address => RewardSpin)) public rewardSpin;
    mapping(bytes32 => mapping(uint256 => uint256)) public numberRewardSpin;

    function name() public view returns (string memory) {
        return _name;
    }

    function setToken(address _token) public override {
        require(address(token) == address(0), "not set token");
        token = IERC20(_token);
    }

    function setOwner(address _owner) public override {
        require(ownerWallet == address(0), "not set ownerWallet");
        ownerWallet = _owner;
    }

    function createGame(
        string memory _title,
        uint256 _price,
        uint256 _startPrice,
        uint256 _affiliatePercent,
        uint256 _ownerPercent,
        uint256 jackpotPercent,
        uint256[] memory values,
        uint256[] memory percents
    ) public {
        require(_price > 0, "price is zero");
        require(_startPrice > 0, "price is zero");
        require(_affiliatePercent < 10, "affiliate percent < 10%");
        require(_ownerPercent < 10, "owner percent < 10%");
        require(values.length == 11 && percents.length == 11, "value and percent is not valid");
        indexGame += 1;
        gameInfo[indexGame].price = _price;
        gameInfo[indexGame].startPrize = _startPrice;
        gameInfo[indexGame].title = _title;
        gameInfo[indexGame].ownerPercent = _ownerPercent;
        gameInfo[indexGame].affiliatePercent = _affiliatePercent;
        for (uint256 index = 0; index < 11; index++) {
            prize[indexGame][index].value = values[index];
            prize[indexGame][index].percent = percents[index];
        }
        uint256 currentPrice = token.balanceOf(address(this));
        require(token.balanceOf(_msgSender()) >= _startPrice, "Insufficient funds in the account");
        token.transferFrom(_msgSender(), address(this), _startPrice);
        uint256 newPrice = token.balanceOf(address(this));
        prize[indexGame][11].percent = jackpotPercent;
        prize[indexGame][11].value = newPrice - currentPrice;
    }

    function playGame(
        uint256 devPercent,
        uint256 sytemFee,
        address sponsorAddress,
        address devWallet,
        address mktWallet,
        uint256 idGame,
        uint256 qty,
        uint256 tokenId
    ) public override nonReentrant {
        require(gameInfo[idGame].price > 0, "Game not found");
        uint256 amount = gameInfo[idGame].price * qty;
        uint256 currentPrice = token.balanceOf(address(this));
        require(token.balanceOf(_msgSender()) >= amount, "Insufficient funds in the account");
        token.transferFrom(_msgSender(), address(this), amount);
        uint256 newPrice = token.balanceOf(address(this));
        uint256 afterFee = newPrice - currentPrice;
        uint256 devFee = amount * (sytemFee / PERCENTS_DIVIDER) * (sytemFee / devPercent);
        token.transfer(devWallet, devFee);
        uint256 mktFee = (amount * (sytemFee / PERCENTS_DIVIDER)) - devFee;
        token.transfer(mktWallet, mktFee);
        uint256 affFee = amount * (gameInfo[idGame].affiliatePercent / PERCENTS_DIVIDER);
        token.transfer(sponsorAddress, affFee);
        uint256 ownerFee = amount * (gameInfo[idGame].ownerPercent / PERCENTS_DIVIDER);
        token.transfer(ownerWallet, ownerFee);
        gameInfo[idGame].totalSpin += qty;
        uint256 totalReward = 0;
        uint256 jackpotPrice = 0;
        uint256 _idGame = idGame;
        bytes32 hash = keccak256(abi.encodePacked(block.number, _msgSender()));
        for (uint256 i = 0; i < qty; i++) {
            (uint256 _totalReward, bool jackpot) = spin(i, hash, _idGame);
            totalReward += _totalReward;
            if (jackpot) {
                jackpotPrice = _totalReward;
                for (uint256 n = i; n >= 0; n--) {
                    delete numberRewardSpin[hash][n];
                }
                numberRewardSpin[hash][0] = jackpotPrice;
                break;
            }
        }

        rewardSpin[hash][_msgSender()].jackpot = jackpotPrice > 0;
        rewardSpin[hash][_msgSender()].qty = qty;
        rewardSpin[hash][_msgSender()].tokenId = tokenId;

        // has jackpot
        if (jackpotPrice > 0) {
            uint256 taxJackpot = (jackpotPrice * 10) / 100;
            uint256 startPrize = gameInfo[_idGame].startPrize;
            if (startPrize <= taxJackpot) {
                prize[_idGame][11].value = (startPrize + afterFee) - devFee - mktFee - affFee - ownerFee;
            } else {
                prize[_idGame][11].value = (taxJackpot + afterFee) - devFee - mktFee - affFee - ownerFee;
            }
            totalReward = jackpotPrice - taxJackpot;
            token.transfer(_msgSender(), totalReward);
            gameInfo[_idGame].term += 1;
            gameInfo[_idGame].totalReward += totalReward;
        } else {
            if (totalReward > 0) {
                token.transfer(_msgSender(), totalReward);
            }
            gameInfo[_idGame].totalReward += totalReward;
            prize[_idGame][11].value = (prize[_idGame][11].value + afterFee) - totalReward - devFee - mktFee - affFee - ownerFee;
        }
    }

    function spin(uint256 number, bytes32 hash, uint256 idGame) internal returns (uint256 reward, bool jackpot) {
        uint256 rSpin = random(block.number % 12);
        jackpot = false;
        for (uint256 n = 0; n < 12; n++) {
            if (prize[idGame][n].percent > 0 && rSpin <= prize[idGame][n].percent) {
                numberRewardSpin[hash][number] = prize[idGame][n].value;
                reward = prize[idGame][n].value;
                if (n == 11) {
                    jackpot = true;
                }
                break;
            }
        }
        return (reward, jackpot);
    }

    function random(uint256 number) internal returns (uint percent){
        nonce += 1;
        return uint(keccak256(abi.encodePacked(
                nonce,
                block.number.add(nonce + number),
                block.timestamp.add(nonce + number),
                block.prevrandao.add(nonce + number),
                _msgSender()
            ))) % SPIN_PERCENTS_DIVIDER;
    }
}