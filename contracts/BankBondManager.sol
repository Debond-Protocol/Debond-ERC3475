// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "./interfaces/IDebondBond.sol";
import "./interfaces/IRedeemableBondCalculator.sol";
import "debond-governance/contracts/utils/GovernanceOwnable.sol";
import "./DebondERC3475.sol";


contract BankBondManager is GovernanceOwnable {

    enum InterestRateType {FixedRate, FloatingRate}

    address debondBondAddress;

    mapping(address => mapping(InterestRateType => uint256)) tokenRateTypeTotalSupply; // needed for interest rate calculation also
    mapping(address => uint256[]) classIdsPerTokenAddress;

    mapping(uint256 => address) fromBondValueToTokenAddress;
    mapping(address => uint256 ) tokenAddressValueMapping;

    mapping (address => bool) tokenAddressExist;
    uint256 tokenAddressCount;

    constructor(
        address _governanceAddress,
        address _debondBondAddress
    ) GovernanceOwnable(_governanceAddress) {
        debondBondAddress = _debondBondAddress;
    }


    // WRITE

    function classExists(uint256 classId) public view returns (bool) {
        return classes[classId].exists;
    }

    function nonceExists(uint256 classId, uint256 nonceId) public view returns (bool) {
        return classes[classId].nonces[nonceId].exists;
    }

    function issue(address to, uint256 classId, uint256 nonceId, uint256 amount) external override onlyRole(ISSUER_ROLE) {

        tokenRateTypeTotalSupply[class.tokenAddress][class.interestRateType] += amount;

    }

    function createClass(uint256 classId, string memory _symbol, InterestRateType interestRateType, address tokenAddress, uint256 periodTimestamp) public override onlyGovernance {
        uint tokenInterestValue = uint256(interestRateType);
        if (!tokenAddressExist[tokenAddress]) {
            ++tokenAddressCount;
            tokenAddressValueMapping[tokenAddress] = tokenAddressCount;
        }
        uint tokenAddressValue = tokenAddressValueMapping[tokenAddress];

        uint[] values = [tokenAddressValue, tokenInterestValue, periodTimestamp];
        _createClass(classId, values);
        classIdsPerTokenAddress[tokenAddress].push(classId);
    }

    function _createClass(uint256 classId, string symbol, uint256[] calldata values) internal {
        require(!classExists(classId), "ERC3475: cannot create a class that already exists");
        DebondERC3475(debondBondAddress).createClass(classId, symbol, values);
    }

    function createNonce(uint256 classId, uint256 nonceId, uint256 _maturityDate) external override onlyRole(ISSUER_ROLE) {
        uint[] values = [block.timestamp, _maturityDate];
        DebondERC3475(debondBondAddress).createNonce(classId, nonceId, values);
    }

    function updateLastNonce(uint classId, uint nonceId, uint createdAt) external onlyRole(ISSUER_ROLE) {
        DebondERC3475(debondBondAddress).updateLastNonce(classId, nonceId, createdAt);
    }
    // READS

    function bondDetails(uint256 classId, uint256 nonceId) public view override returns (string memory _symbol, InterestRateType _interestRateType, address _tokenAddress, uint256 _periodTimestamp, uint256 _issuanceDate, uint256 _maturityDate) {
        uint[] classValues = IERC3475(debondBondAddress).classInfos(classId);
        uint[] nonceValues = IERC3475(debondBondAddress).nonceInfos(classId, nonceId);

        _symbol = IERC3475(debondBondAddress).symbol(classId);
        _interestRateType = classValues[1] == 0 ? InterestRateType.FixedRate : InterestRateType.FloatingRate;
        _tokenAddress = fromBondValueToTokenAddress[classValues[0]];
        _periodTimestamp = classValues[2];
        _issuanceDate = nonceValues[0];
        _maturityDate = nonceValues[1];
    }

    function tokenTotalSupply(address tokenAddress) public view returns (uint256) {
        return tokenRateTypeTotalSupply[tokenAddress][InterestRateType.FloatingRate] + tokenRateTypeTotalSupply[tokenAddress][InterestRateType.FixedRate];
    }

    function tokenLiquidityFlow(address tokenAddress, uint256 nonceNumber, uint256 fromDate) external view returns (uint256) {
        uint liquidityIn;
        uint nonceFromDate = IRedeemableBondCalculator.getNonceFromDate(fromDate);
        for (uint i = nonceFromDate; i >= nonceFromDate - nonceNumber; i-- ) {
            for (uint j = 0; j < classIdsPerTokenAddress.length; j++ ) {
                Nonce storage nonce = classes[classIdsPerTokenAddress[j]].nonces[i];
                liquidityIn += (nonce._activeSupply + nonce._redeemedSupply);
            }
        }
        return liquidityIn;
    }

    function bondAmountDue(address tokenAddress, InterestRateType interestRateType) external view returns (uint256) {
        return tokenRateTypeTotalSupply[tokenAddress][interestRateType];
    }

}
