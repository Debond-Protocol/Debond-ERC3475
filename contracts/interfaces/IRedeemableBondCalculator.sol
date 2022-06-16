pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

interface IRedeemableBondCalculator {

    function getProgress(uint256 classId, uint256 nonceId) external view returns (uint256 progressAchieved, uint256 progressRemaining);

    function getNonceFromDate(uint256 timestampDate) external view returns (uint256);

}
