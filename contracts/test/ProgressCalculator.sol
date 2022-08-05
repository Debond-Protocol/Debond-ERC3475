pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT


import "../interfaces/IProgressCalculator.sol";
import "erc3475/IERC3475.sol";
import "../DebondERC3475.sol";


contract ProgressCalculator is IProgressCalculator {

    address bondContract;

    constructor(address _bondContract) {
        bondContract = _bondContract;
    }

    function getProgress(uint256 classId, uint256 nonceId) external pure returns (uint256 progressAchieved, uint256 progressRemaining) {
        progressAchieved = 100;
        progressRemaining = 0;
    }

    function redeem(address from, IERC3475.Transaction[] calldata transactions) external {
        DebondERC3475(bondContract).redeem(from, transactions);
    }
}
