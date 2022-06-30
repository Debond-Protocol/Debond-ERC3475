pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

interface IProgressCalculator {

    function getProgress(uint256 classId, uint256 nonceId) external view returns (uint256 progressAchieved, uint256 progressRemaining);
}
