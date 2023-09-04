// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IMegaJackpot {
    function playGame(
        uint256 devPercent,
        uint256 sytemFee,
        address sponsorAddress,
        address devWallet,
        address mktWallet,
        uint256 idGame,
        uint256 qty,
        uint256 tokenId
    ) external;

    function setToken(address Token) external;
    function setOwner(address _owner) external;
}