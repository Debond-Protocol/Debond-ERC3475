pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT


import "../interfaces/ILiquidityRedeemable.sol";
import "erc3475/IERC3475.sol";


contract LiquidityRedeemable is ILiquidityRedeemable {

    address debondBondAddress;

    constructor(address _debondBondAddress) {
        debondBondAddress = _debondBondAddress;
    }

    modifier onlyDebondBond() {
        require(msg.sender == debondBondAddress, "LiquidityRedeemable Error: Not Authorised");
        _;
    }

    function redeemLiquidity(address _from, IERC3475.Transaction[] calldata _transactions) external onlyDebondBond {
        return;
    }
}
