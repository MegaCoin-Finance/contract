// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IMegaJackpot {
    event Order(
        uint256 idGame,
        uint256 totalReward,
        bool jackpot,
        uint256 devFee,
        uint256 mktFee,
        uint256 affFee,
        uint256 ownerFee
    );
    event CreateGame(
        string _title,
        uint256 _price,
        uint256 _startPrice,
        uint256 _affiliatePercent,
        uint256 _ownerPercent,
        uint256 jackpotPercent,
        uint256[] values,
        uint256[] percents,
        uint256 idGame,
        string nameContract
    );
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
    ) external;

    function setToken(address Token) external;
    function setProjectOwnerWallet(address _owner) external;
}