// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IMegaJackpot {
    function order(
        uint256 devPercent,
        uint256 sytemFee,
        address sponsorAddress,
        address devWallet,
        address mktWallet,
        uint256 idGame,
        uint256 tokenId,
        uint256 qty
    ) external;

    function setToken(address Token) external;
    function setProjectOwnerWallet(address _owner) external;
}