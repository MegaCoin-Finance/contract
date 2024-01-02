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

    event DeployedGame(
        string projectId,
        address contractGameNew,
        address projectOwner,
        address contractGameOrigin,
        address contractToken, 
        uint256 deployedFee,
        uint256 affFee,
        uint256 devFee,
        uint256 mktFee
    );
    event Order(address contractGame, uint256 idGame, uint256 tokenId, uint256 qty);

    string private _name = "Mega Factory V1";
    MegaItemsCore public MegaItemsNFT;
    uint256 constant public PERCENTS_DIVIDER = 1000;
    address public projectWallet = 0x071a5B1451c55153Df15243d0Ff64c8078F75E46;
    address payable public devWallet = payable(0x071a5B1451c55153Df15243d0Ff64c8078F75E46);
    address payable public mktWallet = payable(0x071a5B1451c55153Df15243d0Ff64c8078F75E46);
    address payable public topAddress = payable(0x071a5B1451c55153Df15243d0Ff64c8078F75E46);
    uint256 public deployedFee = 0.002 ether;
    uint256 public affPercent = 100;
    uint256 public devPercent = 200;
    uint256 public sytemFee = 10;
    mapping(address => bool) public listGame;
    mapping (address => mapping (address => bool)) public validate;
    mapping (address => mapping (string => address)) public project;
    mapping (address => mapping (string => bool)) public checkUnique;

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
    //0x0000000000000000000000000000000000000000
    function deployedGame(address game, address token, string memory projectId) public payable {
        require(listGame[game] == true, "Game not found");
        require(msg.value >= deployedFee, "Invalid amount");
        require(address(MegaItemsNFT) != address(0), "Contract NFT not found");
        require(validate[_msgSender()][token] == false, "This contract token created by this user");
        require(checkUnique[game][projectId] == false, "This project created");
        if(token == address(0)) {
            require(_msgSender() == projectWallet, "Projects cannot be created with native tokens");
        }
        uint256 affFee = deployedFee.mul(affPercent).div(PERCENTS_DIVIDER);
        uint256 devFee = deployedFee.mul(devPercent).div(PERCENTS_DIVIDER);
        uint256 mktFee = deployedFee.sub(affFee).sub(devFee);
        topAddress.transfer(affFee);
        devWallet.transfer(devFee);
        mktWallet.transfer(mktFee);
        address gameClone = createClone(game);
        IMegaJackpot(gameClone).setToken(token);
        IMegaJackpot(gameClone).setProjectOwnerWallet(_msgSender());
        validate[_msgSender()][token] = true;
        project[game][projectId] = gameClone;
        checkUnique[game][projectId] = true;
        emit DeployedGame(projectId, gameClone, _msgSender(), game, token, deployedFee, affFee, devFee, mktFee);
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
            qty,
            _msgSender()
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