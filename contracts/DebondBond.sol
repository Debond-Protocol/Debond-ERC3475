// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "./interfaces/IDebondBond.sol";
import "./interfaces/IRedeemableBondCalculator.sol";
import "debond-governance/contracts/utils/GovernanceOwnable.sol";
import "./DebondERC3475.sol";


contract DebondBond is DebondERC3475, IDebondBond, GovernanceOwnable {

    address redeemableBondCalculatorAddress;

    mapping(address => mapping(IDebondBond.InterestRateType => uint256)) tokenRateTypeTotalSupply; // needed for interest rate calculation also
    mapping(address => uint256[]) classIdsPerTokenAddress;

    constructor(
        address _governanceAddress,
        address _redeemableBondCalculatorAddress
    ) GovernanceOwnable(_governanceAddress) {
        redeemableBondCalculatorAddress = _redeemableBondCalculatorAddress;
    }


    // WRITE

    function classExists(uint256 classId) public view returns (bool) {
        return classes[classId].exists;
    }

    function nonceExists(uint256 classId, uint256 nonceId) public view returns (bool) {
        return classes[classId].nonces[nonceId].exists;
    }

    function issue(address to, uint256 classId, uint256 nonceId, uint256 amount) external override onlyRole(ISSUER_ROLE) {
        require(classes[classId].exists, "ERC3475: only issue bond that has been created");
        require(classes[classId].nonces[nonceId].exists, "ERC-3475: nonceId given not found!");
        require(to != address(0), "ERC3475: can't transfer to the zero address");
        _issue(to, classId, nonceId, amount);

        if (!classesPerHolder[to][classId]) {
            classesPerHolderArray[to].push(classId);
            classesPerHolder[to][classId] = true;
        }

        Class storage class = classes[classId];
        class.liquidity += amount;
        tokenRateTypeTotalSupply[class.tokenAddress][class.interestRateType] += amount;

        if (!class.noncesPerAddress[to][nonceId]) {
            class.noncesPerAddressArray[to].push(nonceId);
            class.noncesPerAddress[to][nonceId] = true;
        }

        Nonce storage nonce = class.nonces[nonceId];
        nonce.classLiquidity = class.liquidity + amount;
        emit Issue(msg.sender, to, classId, nonceId, amount);
    }

    function createClass(uint256 classId, string memory _symbol, InterestRateType interestRateType, address tokenAddress, uint256 periodTimestamp) public override onlyGovernance {
        _createClass(classId, _symbol, interestRateType, tokenAddress, periodTimestamp);
        classIdsPerTokenAddress[tokenAddress].push(classId);
    }

    function _createClass(uint256 classId, string memory _symbol, InterestRateType interestRateType, address tokenAddress, uint256 periodTimestamp) internal {
        require(!classExists(classId), "ERC3475: cannot create a class that already exists");
        Class storage class = classes[classId];
        class.id = classId;
        class.exists = true;
        class.symbol = _symbol;
        class.interestRateType = interestRateType;
        class.tokenAddress = tokenAddress;
        class.periodTimestamp = periodTimestamp;
    }

    function createNonce(uint256 classId, uint256 nonceId, uint256 _maturityDate) external override onlyRole(ISSUER_ROLE) {
        require(classExists(classId), "ERC3475: only issue bond that has been created");
        Class storage class = classes[classId];

        Nonce storage nonce = class.nonces[nonceId];
        require(!nonce.exists, "Error ERC-3475: nonceId exists!");

        nonce.id = nonceId;
        nonce.exists = true;
        nonce.maturityDate = _maturityDate;
        nonce.issuanceDate = block.timestamp;
    }

    function updateLastNonce(uint classId, uint nonceId, uint createdAt) external onlyRole(ISSUER_ROLE) {
        Class storage class = classes[classId];
        require(class.exists, "Debond Data: class id given not found");
        class.lastNonceIdCreated = nonceId;
        class.lastNonceIdCreatedTimestamp = createdAt;
    }

    function setRedeemableBondCalculatorAddress(address _redeemableBondCalculatorAddress) external onlyGovernance {
        require(_redeemableBondCalculatorAddress != address(0), "null Address given");
        redeemableBondCalculatorAddress = _redeemableBondCalculatorAddress;
    }
    // READS

    function getClassesPerTokenAddress(address tokenAddress) external view returns (uint256[] memory) {
        return classesPerHolderArray[tokenAddress];
    }

    function bondDetails(uint256 classId, uint256 nonceId) public view override returns (string memory _symbol, InterestRateType _interestRateType, address _tokenAddress, uint256 _periodTimestamp, uint256 _issuanceDate, uint256 _maturityDate, uint256 _tokenLiquidity) {
        Class storage class = classes[classId];
        Nonce storage nonce = class.nonces[nonceId];

        _symbol = class.symbol;
        _interestRateType = class.interestRateType;
        _tokenAddress = class.tokenAddress;
        _periodTimestamp = class.periodTimestamp;
        _issuanceDate = nonce.issuanceDate;
        _maturityDate = nonce.maturityDate;
        _tokenLiquidity = nonce.classLiquidity;

        return (_symbol, _interestRateType, _tokenAddress, _periodTimestamp, _issuanceDate, _maturityDate, _tokenLiquidity);
    }

    function tokenTotalSupply(address tokenAddress) public view returns (uint256) {
        return tokenRateTypeTotalSupply[tokenAddress][InterestRateType.FloatingRate] + tokenRateTypeTotalSupply[tokenAddress][InterestRateType.FixedRate];
    }

    function isRedeemable(uint256 classId, uint256 nonceId) public override view returns (bool) {
        return IRedeemableBondCalculator(redeemableBondCalculatorAddress).isRedeemable(classId, nonceId);

    }

    function bondAmountDue(address tokenAddress, InterestRateType interestRateType) external view returns (uint256) {
        return tokenRateTypeTotalSupply[tokenAddress][interestRateType];
    }

    function getLastNonceCreated(uint classId) external view returns (uint nonceId, uint createdAt) {
        Class storage class = classes[classId];
        require(class.exists, "Debond Data: class id given not found");
        nonceId = class.lastNonceIdCreated;
        createdAt = class.lastNonceIdCreatedTimestamp;
        return (nonceId, createdAt);
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

    function tokenSupplyAtNonce(address tokenAddress, uint256 nonceId) external view returns (uint256) {
        uint supply;
        for (uint i = 0; i < classIdsPerTokenAddress.length; i++ ) {
            Class storage class = classes[classIdsPerTokenAddress[i]];
            Nonce storage nonce = class.nonces[nonceId];
            supply += !nonce.exists ? class.nonces[class.lastNonceIdCreated].classLiquidity : nonce.classLiquidity;
        }
        return supply;
    }



    function getNoncesPerAddress(address addr, uint256 classId) public view returns (uint256[] memory) {
        return classes[classId].noncesPerAddressArray[addr];
    }

    function batchActiveSupply(uint256 classId) public view returns (uint256) {
        uint256 _batchActiveSupply;
        uint256[] memory nonces = classes[classId].nonceIds;
        // _lastBondNonces can be recovered from the last message of the nonceId
        // @drisky we can indeed
        for (uint256 i = 0; i <= nonces.length; i++) {
            _batchActiveSupply += activeSupply(classId, nonces[i]);
        }
        return _batchActiveSupply;
    }

    function batchBurnedSupply(uint256 classId) public view returns (uint256) {
        uint256 _batchBurnedSupply;
        uint256[] memory nonces = classes[classId].nonceIds;

        for (uint256 i = 0; i <= nonces.length; i++) {
            _batchBurnedSupply += burnedSupply(classId, nonces[i]);
        }
        return _batchBurnedSupply;
    }

    function batchRedeemedSupply(uint256 classId) public view returns (uint256) {
        uint256 _batchRedeemedSupply;
        uint256[] memory nonces = classes[classId].nonceIds;

        for (uint256 i = 0; i <= nonces.length; i++) {
            _batchRedeemedSupply += redeemedSupply(classId, nonces[i]);
        }
        return _batchRedeemedSupply;
    }

    function batchTotalSupply(uint256 classId) public view returns (uint256) {
        uint256 _batchTotalSupply;
        uint256[] memory nonces = classes[classId].nonceIds;

        for (uint256 i = 0; i <= nonces.length; i++) {
            _batchTotalSupply += totalSupply(classId, nonces[i]);
        }
        return _batchTotalSupply;
    }
}
