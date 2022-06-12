// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "./interfaces/IDebondBond.sol";
import "./interfaces/IRedeemableBondCalculator.sol";
import "debond-governance/contracts/utils/GovernanceOwnable.sol";
import "./DebondERC3475.sol";


contract BankBondManager is GovernanceOwnable {

    enum InterestRateType {FixedRate, FloatingRate}

    address debondBondAddress;

    mapping(address => mapping(InterestRateType => uint256)) public tokenRateTypeTotalSupply; // needed for interest rate calculation also
    mapping(address => mapping(uint256 => uint256)) tokenTotalSupplyAtNonce;
    mapping(address => uint256[]) classIdsPerTokenAddress;

    mapping(uint256 => address) public fromBondValueToTokenAddress;
    mapping(address => uint256) public tokenAddressValueMapping;

    mapping (address => bool) public tokenAddressExist;
    uint256 tokenAddressCount;

    constructor(
        address _governanceAddress,
        address _debondBondAddress
    ) GovernanceOwnable(_governanceAddress) {
        debondBondAddress = _debondBondAddress;
    }

    function issue(address to, uint256 classId, uint256 nonceId, uint256 amount) internal {
        (address tokenAddress, InterestRateType interestRateType,) = classValues(classId);
        DebondERC3475(debondBondAddress).issue(to, classId, nonceId, amount);
        tokenRateTypeTotalSupply[tokenAddress][interestRateType] += amount;
        tokenTotalSupplyAtNonce[tokenAddress][nonceId] = tokenTotalSupply(tokenAddress);

    }

    function createClass(uint256 classId, string memory _symbol, InterestRateType interestRateType, address tokenAddress, uint256 periodTimestamp) public onlyGovernance {
        require(!DebondERC3475(debondBondAddress).classExists(classId), "ERC3475: cannot create a class that already exists");
        uint interestRateTypeValue = uint256(interestRateType);
        if (!tokenAddressExist[tokenAddress]) {
            ++tokenAddressCount;
            tokenAddressValueMapping[tokenAddress] = tokenAddressCount;
        }
        uint tokenAddressValue = tokenAddressValueMapping[tokenAddress];

        uint256[] memory values;
        values[0] = tokenAddressValue;
        values[1] = interestRateTypeValue;
        values[2] = periodTimestamp;
        DebondERC3475(debondBondAddress).createClass(classId, _symbol, values);
        classIdsPerTokenAddress[tokenAddress].push(classId);
    }

    function createNonce(uint256 classId, uint256 nonceId, uint256 _maturityDate) internal {
        uint256[] memory values;
        values[0] = block.timestamp;
        values[1] = _maturityDate;
        DebondERC3475(debondBondAddress).createNonce(classId, nonceId, values);
    }

    function updateLastNonce(uint classId, uint nonceId, uint createdAt) internal {
        DebondERC3475(debondBondAddress).updateLastNonce(classId, nonceId, createdAt);
    }
    // READS

    function classValues(uint256 classId) public view returns (address _tokenAddress, InterestRateType _interestRateType, uint256 _periodTimestamp) {
        uint[] memory _classValues = IERC3475(debondBondAddress).classInfos(classId);

        _interestRateType = _classValues[1] == 0 ? InterestRateType.FixedRate : InterestRateType.FloatingRate;
        _tokenAddress = fromBondValueToTokenAddress[_classValues[0]];
        _periodTimestamp = _classValues[2];
    }

    function nonceValues(uint256 classId, uint256 nonceId) public view returns (uint256 _issuanceDate, uint256 _maturityDate) {
        uint[] memory _nonceValues = IERC3475(debondBondAddress).nonceInfos(classId, nonceId);
        _issuanceDate = _nonceValues[0];
        _maturityDate = _nonceValues[1];
    }

    function tokenTotalSupply(address tokenAddress) public view returns (uint256) {
        return tokenRateTypeTotalSupply[tokenAddress][InterestRateType.FloatingRate] + tokenRateTypeTotalSupply[tokenAddress][InterestRateType.FixedRate];
    }

    function supplyIssuedOnPeriod(address tokenAddress, uint256 fromNonceId, uint256 toNonceId) internal view returns (uint256 supply) {
        require(fromNonceId <= toNonceId, "DebondBond Error: Invalid Input");
        // we loop on every nonces required of every token's classes
        for (uint i = fromNonceId; i <= toNonceId; i++ ) {
            for (uint j = 0; j < classIdsPerTokenAddress[tokenAddress].length; j++ ) {
                supply += (IERC3475(debondBondAddress).activeSupply(classIdsPerTokenAddress[tokenAddress][j], i) + IERC3475(debondBondAddress).redeemedSupply(classIdsPerTokenAddress[tokenAddress][j], i));
            }
        }
    }

}
