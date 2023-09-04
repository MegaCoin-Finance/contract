// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./IERC20.sol";
import "./ERC1155.sol";

contract MegaNFTContract is MegaItemsCore, ERC1155 {
    using SafeMath for uint256;
    using Strings for uint256;
    using Address for address;

    event AddMegaFactory(uint256 indexed tokenId);

    mapping(uint256 => MegaItems) private MegaFactory;
    mapping(address => bool) private activeSafeMintNFT;

    modifier onlySafeNFT() {
        require(activeSafeMintNFT[_msgSender()] == true, "require Safe Address.");
        _;
    }

    constructor(
        string memory baseURI
    ) ERC1155(baseURI, "Mega NFT", "Mega-NFT") {}

    /**
     * @dev Withdraw bnb from this contract (Callable by owner only)
     */
    function SwapExactToken(address coinAddress, uint256 value, address payable to) public onlyOwner {
        if (coinAddress == address(0)) {
            return to.transfer(value);
        }
        IERC20(coinAddress).transfer(to, value);
    }

    function setSafeMintNFT(address _mint, bool active) public onlyOwner {
        activeSafeMintNFT[_mint] = active;
    }

    function safeMintNFT(address _addr, uint256 tokenId, uint256 amount) external override onlySafeNFT {
        _mint(_addr, tokenId, amount, "0x0");
    }

    function safeBatchMintNFT(address _addr, uint256[] memory tokenId, uint256[] memory amount) external override onlySafeNFT {
        _mintBatch(_addr, tokenId, amount, "0x0");
    }

    function burnNFT(address _addr, uint256 tokenId, uint256 amount) external override {
        _burn(_addr, tokenId, amount);
    }

    function burnBatchNFT(address _addr, uint256[] memory ids, uint256[] memory amounts) external override {
        _burnBatch(_addr, ids, amounts);
    }

    /**
    * @dev Changes the base URI if we want to move things in the future (Callable by owner only)
    */
    function changeBaseURI(string memory baseURI) public onlyOwner {
        _setURI(baseURI);
    }

    function getNextNFTId() external view override returns (uint256){
        return totalSupply().add(1);
    }
}
