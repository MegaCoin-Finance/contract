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

    string private _name = "Mega Jackpot V1";
    uint256 constant public PERCENTS_DIVIDER = 1000;
    uint256 constant public SPIN_PERCENTS_DIVIDER = 1000_000_000;
    IERC20 public token;
    uint256 public indexGame = 0;
    uint256 public nonce = 0;
    address public projectOwnerWallet;

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
    mapping(uint256 => RewardSpin) public orders;
    mapping(uint256 => mapping(uint256 => uint256)) public orderRewards;

    function name() public view returns (string memory) {
        return _name;
    }

    function setToken(address _token) public override {
        require(address(token) == address(0), "Not set token");
        token = IERC20(_token);
    }

    function setProjectOwnerWallet(address _owner) public override {
        require(projectOwnerWallet == address(0), "Not set ownerWallet");
        projectOwnerWallet = _owner;
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
        require(_msgSender() == projectOwnerWallet, "Project owner required");
        require(_price > 0, "Price must > 0");
        require(_startPrice > 0, "Start price must > 0");
        require((_affiliatePercent) <= 100, "Affiliate percent must < 10%");
        require((_ownerPercent) <= 100, "Owner percent must < 10%");
        require(values.length == 11 && percents.length == 11, "Value or percent is not valid");
        indexGame += 1;
        gameInfo[indexGame].price = _price;
        gameInfo[indexGame].startPrize = _startPrice;
        gameInfo[indexGame].title = _title;
        gameInfo[indexGame].ownerPercent = _ownerPercent;
        gameInfo[indexGame].affiliatePercent = _affiliatePercent;
        uint256 totalPercentPrize = 0;
        uint256 currentPrice = token.balanceOf(address(this));
        require(token.balanceOf(projectOwnerWallet) >= _startPrice, "Insufficient funds");
        token.transferFrom(projectOwnerWallet, address(this), _startPrice);
        uint256 newPrice = token.balanceOf(address(this));
        for (uint256 index = 0; index < 12; index++) {
            if(index == 0) {
                prize[indexGame][index].percent = jackpotPercent;
                prize[indexGame][index].value = newPrice - currentPrice;
                totalPercentPrize += jackpotPercent;
            } else {
                prize[indexGame][index].value = values[index - 1];
                prize[indexGame][index].percent = totalPercentPrize + percents[index - 1];
                totalPercentPrize += percents[index - 1];
            }
        }
        require(totalPercentPrize ==  SPIN_PERCENTS_DIVIDER, "Total percent prize must = 100%");
        emit CreateGame(
            _title,
            _price,
            _startPrice,
            _affiliatePercent,
            _ownerPercent,
            jackpotPercent,
            values,
            percents,
            indexGame,
            "Mega_Jackpot_V1",
            address(this)
        );
    }

    function order(
        uint256 devPercent,
        uint256 sytemFee,
        address sponsorAddress,
        address devWallet,
        address mktWallet,
        uint256 idGame,
        uint256 tokenId,
        uint256 qty,
        address userSpin
    ) public override nonReentrant {
        require(qty <= 10, "Quantity must <= 10");
        require(gameInfo[idGame].price > 0, "Game not found");
        uint256 amount = gameInfo[idGame].price * qty;
        uint256 currentPrice = token.balanceOf(address(this));
        require(token.balanceOf(userSpin) >= amount, "Insufficient funds");
        token.transferFrom(userSpin, address(this), amount);
        uint256 newPrice = token.balanceOf(address(this));
        uint256 afterFee = newPrice - currentPrice;
        uint256 devFee = amount * sytemFee / PERCENTS_DIVIDER * devPercent / PERCENTS_DIVIDER;
        token.transfer(devWallet, devFee);
        uint256 mktFee = amount * sytemFee / PERCENTS_DIVIDER - devFee;
        token.transfer(mktWallet, mktFee);
        uint256 affFee = amount * gameInfo[idGame].affiliatePercent / PERCENTS_DIVIDER;
        token.transfer(sponsorAddress, affFee);
        uint256 ownerFee = amount * gameInfo[idGame].ownerPercent / PERCENTS_DIVIDER;
        token.transfer(projectOwnerWallet, ownerFee);
        gameInfo[idGame].totalSpin += qty;
        uint256 totalReward = 0;
        uint256 jackpotPrice = 0;
        uint256 _idGame = idGame;
        uint256 _tokenId = tokenId;
        for (uint256 i = 0; i < qty; i++) {
            (uint256 _totalReward, bool jackpot) = spin(i, _tokenId, _idGame);
            totalReward += _totalReward;
            if (jackpot) {
                jackpotPrice = _totalReward;
                for (uint256 n = i; n > 0; n--) {
                    delete orderRewards[_tokenId][n];
                }
                orderRewards[_tokenId][0] = jackpotPrice;
                break;
            }
        }

        orders[_tokenId].jackpot = jackpotPrice > 0;
        orders[_tokenId].qty = qty;
        orders[_tokenId].tokenId = _tokenId;

        // has jackpot
        if (jackpotPrice > 0) {
            uint256 taxJackpot = (jackpotPrice * 10) / 100;
            uint256 startPrize = gameInfo[_idGame].startPrize;
            if (startPrize <= taxJackpot) {
                prize[_idGame][0].value = (startPrize + afterFee) - devFee - mktFee - affFee - ownerFee;
            } else {
                prize[_idGame][0].value = (taxJackpot + afterFee) - devFee - mktFee - affFee - ownerFee;
            }
            totalReward = jackpotPrice - taxJackpot;
            gameInfo[_idGame].term += 1;
            gameInfo[_idGame].totalReward += totalReward;
        } else {
            gameInfo[_idGame].totalReward += totalReward;
            prize[_idGame][0].value = (prize[_idGame][0].value + afterFee) - totalReward - devFee - mktFee - affFee - ownerFee;
        }
        if (totalReward > 0) {
            token.transfer(userSpin, totalReward);
        }
        emit Order(_idGame, totalReward, orders[_tokenId].jackpot, devFee, mktFee, affFee, ownerFee);
    }

    function spin(uint256 number, uint256 _tokenId, uint256 idGame) internal returns (uint256 reward, bool jackpot) {
        uint256 rSpin = random(block.number % 12);
        jackpot = false;
        for (uint256 n = 0; n < 12; n++) {
            if (prize[idGame][n].percent > 0 && rSpin <= prize[idGame][n].percent) {
                orderRewards[_tokenId][number] = prize[idGame][n].value;
                reward = prize[idGame][n].value;
                if (n == 0) {
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
