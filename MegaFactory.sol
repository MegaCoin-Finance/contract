// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./Address.sol";
import "./Context.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./CloneFactory.sol";
import "./SafeMath.sol";
import "./IMegaJackpot.sol";
import "./ReentrancyGuard.sol";
import "./IERC1155.sol";

contract MegaFactoryV1 is CloneFactory, ReentrancyGuard, Ownable {
    using Address for address;
    using SafeMath for uint256;

    event DeployedGame(address gameClone, address _owner);
    event Order(address contractGame, uint256 idGame, uint256 tokenId, uint256 qty);

    string private _name = "Mega Factory V1";
    MegaItemsCore public MegaItemsNFT;
    uint256 constant public PERCENTS_DIVIDER = 1000;
    address payable public devWallet = payable(0x8b9588F69e04D69655e0d866cD701844177360A7);
    address payable public mktWallet = payable(0x8b9588F69e04D69655e0d866cD701844177360A7);
    address payable public topAddress = payable(0x8b9588F69e04D69655e0d866cD701844177360A7);
    uint256 public deployedFee = 0.002 ether;
    uint256 public affPercent = 100;
    uint256 public devPercent = 200;
    uint256 public sytemFee = 10;
    mapping(address => bool) public listGame;

    function name() public view returns (string memory) {
        return _name;
    }

    constructor(
        address contractNFT,
        address game
    ) {
        MegaItemsNFT = MegaItemsCore(contractNFT);
        listGame[game] = true;
    }

    function deployedGame(address game, address token) public payable {
        require(listGame[game] == true, "Game not found");
        require(msg.value >= deployedFee, "The price to send is not correct");
        require(address(MegaItemsNFT) != address(0), "contract NFT not found");
        uint256 affFee = deployedFee.mul(affPercent).div(PERCENTS_DIVIDER);
        uint256 devFee = deployedFee.mul(devPercent).div(PERCENTS_DIVIDER);
        uint256 mktFee = deployedFee.sub(affFee).sub(devFee);
        topAddress.transfer(affFee);
        devWallet.transfer(devFee);
        mktWallet.transfer(mktFee);
        address gameClone = createClone(game);
        IMegaJackpot(gameClone).setToken(token);
        IMegaJackpot(gameClone).setProjectOwnerWallet(_msgSender());
        emit DeployedGame(gameClone, _msgSender());
    }

    function order(address contractGame, uint256 idGame, uint256 qty, address sponsorAddress) public nonReentrant {
        if (sponsorAddress == address(0)) {
            sponsorAddress = topAddress;
        }
        uint256 tokenId = MegaItemsNFT.getNextNFTId();
        MegaItemsNFT.safeMintNFT(_msgSender(), tokenId, qty);
        IMegaJackpot(contractGame).order(
            devPercent,
            sytemFee,
            sponsorAddress,
            devWallet,
            mktWallet,
            idGame,
            tokenId,
            qty
        );
        emit Order(contractGame, idGame, tokenId, qty);
    }
    function setListGame(address game, bool active) public onlyOwner {
        listGame[game] = active;
    }
    function setNFTContract(address nft) public onlyOwner {
        MegaItemsNFT = MegaItemsCore(nft);
    }
    function setDeployFee(uint256 fee) public onlyOwner {
        deployedFee = fee;
    }
    function setAffPercent(uint256 fee) public onlyOwner {
        affPercent = fee;
    }
    function setDevPercent(uint256 fee) public onlyOwner {
        devPercent = fee;
    }
    function setSytemFeePercent(uint256 fee) public onlyOwner {
        sytemFee = fee;
    }
    function setDevWallet(address _wallet) public onlyOwner {
        devWallet = payable(_wallet);
    }
    function setMktWallet(address _wallet) public onlyOwner {
        mktWallet = payable(_wallet);
    }
    function setTopAddress(address _wallet) public onlyOwner {
        topAddress = payable(_wallet);
    }
    function SwapExactToken(
        address coinAddress,
        uint256 value,
        address payable to
    ) public onlyOwner {
        if (coinAddress == address(0)) {
            return to.transfer(value);
        }
        IERC20(coinAddress).transfer(to, value);
    }
    receive() external payable {}
}