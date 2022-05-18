// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "./interfaces/IDebondBond.sol";
import "debond-governance/contracts/utils/GovernanceOwnable.sol";
import "./DebondERC3475.sol";


contract DebondBond is DebondERC3475, IDebondBond, GovernanceOwnable {


    constructor(address governanceAddress) GovernanceOwnable(governanceAddress) { }


    // WRITE

    function classExists(uint256 classId) public view returns (bool) {
        return classes[classId].exists;
    }

    function nonceExists(uint256 classId, uint256 nonceId) public view returns (bool) {
        return classes[classId].nonces[nonceId].exists;
    }

    function createClass(uint256 classId, string memory _symbol, InterestRateType interestRateType, address tokenAddress, uint256 periodTimestamp) public override onlyGovernance {
        _createClass(classId, _symbol, interestRateType, tokenAddress, periodTimestamp);
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
    // READS

    function bondDetails(uint256 classId, uint256 nonceId) public view override returns (string memory _symbol, InterestRateType _interestRateType, address _tokenAddress, uint256 _periodTimestamp, uint256 _issuanceDate, uint256 _maturityDate, uint256 _tokenLiquidity) {
        Class storage class = classes[classId];
        Nonce storage nonce = class.nonces[nonceId];

        _symbol = class.symbol;
        _interestRateType = class.interestRateType;
        _tokenAddress = class.tokenAddress;
        _periodTimestamp = class.periodTimestamp;
        _issuanceDate = nonce.issuanceDate;
        _maturityDate = nonce.maturityDate;
        _tokenLiquidity = nonce.tokenLiquidity;

        return (_symbol, _interestRateType, _tokenAddress, _periodTimestamp, _issuanceDate, _maturityDate, _tokenLiquidity);
    }

    function totalActiveSupply(address tokenAddress) external view returns (uint256) {
        return bondsDue[tokenAddress][InterestRateType.FloatingRate] + bondsDue[tokenAddress][InterestRateType.FixedRate];
    }

    function isRedeemable(uint256 classId, uint256 nonceId) public override view returns (bool) {
        Class storage class = classes[classId];
        if (class.interestRateType == InterestRateType.FixedRate) {
            return classes[classId].nonces[nonceId].maturityDate <= block.timestamp;
        }

        if (class.interestRateType == InterestRateType.FloatingRate) {
            return true;
        }
        return false;

    }

    function bondAmountDue(address tokenAddress, InterestRateType interestRateType) external view returns (uint256) {
        return bondsDue[tokenAddress][interestRateType];
    }

    function getLastNonceCreated(uint classId) external view returns(uint nonceId, uint createdAt) {
        Class storage class = classes[classId];
        require(class.exists, "Debond Data: class id given not found");
        nonceId = class.lastNonceIdCreated;
        createdAt = class.lastNonceIdCreatedTimestamp;
        return (nonceId, createdAt);
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
