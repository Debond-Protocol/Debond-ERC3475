// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IDebondBond.sol";


contract DebondBond is IDebondBond, AccessControl {

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    /**
    * @notice this Struct is representing the Nonce properties as an object
    *         and can be retrieve by the nonceId (within a class)
    */
    struct Nonce {
        uint256 id;
        bool exists;
        uint256 _activeSupply;
        uint256 _burnedSupply;
        uint256 _redeemedSupply;
        uint256 maturityDate;
        uint256 issuanceDate;
        uint256 tokenLiquidity;
        uint256[] infos;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        mapping(address => bool) hasBalance;
    }

    /**
    * @notice this Struct is representing the Class properties as an object
    *         and can be retrieve by the classId
    */
    struct Class {
        uint256 id;
        bool exists;
        string symbol;
        uint256[] infos;
        IData.InterestRateType interestRateType;
        address tokenAddress;
        uint256 periodTimestamp;
        mapping(address => mapping(uint256 => bool)) noncesPerAddress;
        mapping(address => uint256[]) noncesPerAddressArray;
        uint256[] nonceIds;
        mapping(uint256 => Nonce) nonces; // from nonceId given
    }

    mapping(uint256 => Class) internal classes; // from classId given
    string[] public classInfoDescriptions; // mapping with class.infos
    string[] public nonceInfoDescriptions; // mapping with nonce.infos
    mapping(address => mapping(uint256 => bool)) classesPerAddress;
    mapping(address => uint256[]) public classesPerAddressArray;

    mapping(address => mapping(IData.InterestRateType => uint256)) bondsDue;
    mapping(address => mapping(address => bool)) operatorApprovals;


    bool public _isActive;

    constructor() {
        _isActive = true;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


    function isActive() external view returns (bool) {
        return _isActive;
    }

    // WRITE

    function transferFrom(address from, address to, uint256 classId, uint256 nonceId, uint256 amount) public virtual override {
        require(msg.sender == from || isApprovedFor(from, msg.sender), "ERC3475: caller is not owner nor approved");
        _transferFrom(from, to, classId, nonceId, amount);
        emit Transfer(msg.sender, from, to, classId, nonceId, amount);
    }


    function issue(address to, uint256 classId, uint256 nonceId, uint256 amount) external override onlyRole(ISSUER_ROLE) {
        require(classExists(classId), "ERC3475: only issue bond that has been created");
        require(nonceExists(classId, nonceId), "ERC-3475: nonceId given not found!");
        require(to != address(0), "ERC3475: can't transfer to the zero address");
        _issue(to, classId, nonceId, amount);

        if (!classesPerAddress[to][classId]) {
            classesPerAddressArray[to].push(classId);
            classesPerAddress[to][classId] = true;
        }

        Class storage class = classes[classId];
        if (!class.noncesPerAddress[to][nonceId]) {
            class.noncesPerAddressArray[to].push(nonceId);
            class.noncesPerAddress[to][nonceId] = true;
        }

        Nonce storage nonce = class.nonces[nonceId];
        bondsDue[class.tokenAddress][class.interestRateType] += amount;
        nonce.tokenLiquidity = bondsDue[class.tokenAddress][IData.InterestRateType.FixedRate] + bondsDue[class.tokenAddress][IData.InterestRateType.FloatingRate];
        emit Issue(msg.sender, to, classId, nonceId, amount);
    }

    function classExists(uint256 classId) public view returns (bool) {
        return classes[classId].exists;
    }

    function nonceExists(uint256 classId, uint256 nonceId) public view returns (bool) {
        return classes[classId].nonces[nonceId].exists;
    }

    function createClass(uint256 classId, string memory _symbol, IData.InterestRateType interestRateType, address tokenAddress, uint256 periodTimestamp) public override onlyRole(ISSUER_ROLE) {
        _createClass(classId, _symbol, interestRateType, tokenAddress, periodTimestamp);
    }

    function _createClass(uint256 classId, string memory _symbol, IData.InterestRateType interestRateType, address tokenAddress, uint256 periodTimestamp) private {
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

    function redeem(address from, uint256 classId, uint256 nonceId, uint256 amount) external override onlyRole(ISSUER_ROLE) {
        require(nonceExists(classId, nonceId), "ERC3475: given Nonce doesn't exist");
        require(from != address(0), "ERC3475: can't transfer to the zero address");
        require(isRedeemable(classId, nonceId), "Bond is not redeemable");
        _redeem(from, classId, nonceId, amount);
        Class storage class = classes[classId];
        bondsDue[class.tokenAddress][class.interestRateType] -= amount;
        class.nonces[nonceId].tokenLiquidity -= amount;
        emit Redeem(msg.sender, from, classId, nonceId, amount);
    }


    function burn(address from, uint256 classId, uint256 nonceId, uint256 amount) external override onlyRole(ISSUER_ROLE) {
        require(from != address(0), "ERC3475: can't transfer to the zero address");
        _burn(from, classId, nonceId, amount);
        Class storage class = classes[classId];
        bondsDue[class.tokenAddress][class.interestRateType] -= amount;
        emit Burn(msg.sender, from, classId, nonceId, amount);
    }


    function approve(address spender, uint256 classId, uint256 nonceId, uint256 amount) external override {
        classes[classId].nonces[nonceId].allowances[msg.sender][spender] = amount;
    }


    function setApprovalFor(address operator, bool approved) public override {
        operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalFor(msg.sender, operator, approved);
    }


    function batchApprove(address spender, uint256[] calldata classIds, uint256[] calldata nonceIds, uint256[] calldata amounts) external {
        require(classIds.length == nonceIds.length && classIds.length == amounts.length, "ERC3475 Input Error");
        for (uint256 i = 0; i < classIds.length; i++) {
            classes[classIds[i]].nonces[nonceIds[i]].allowances[msg.sender][spender] = amounts[i];
        }
    }
    // READS


    function totalSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return classes[classId].nonces[nonceId]._activeSupply + classes[classId].nonces[nonceId]._redeemedSupply + classes[classId].nonces[nonceId]._burnedSupply;
    }


    function activeSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return classes[classId].nonces[nonceId]._activeSupply;
    }


    function burnedSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return classes[classId].nonces[nonceId]._burnedSupply;
    }


    function redeemedSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return classes[classId].nonces[nonceId]._burnedSupply;
    }


    function balanceOf(address account, uint256 classId, uint256 nonceId) public override view returns (uint256) {
        require(account != address(0), "ERC3475: balance query for the zero address");

        return classes[classId].nonces[nonceId].balances[account];
    }


    function symbol(uint256 classId) public view override returns (string memory) {
        Class storage class = classes[classId];
        return class.symbol;
    }


    function classInfos(uint256 classId) public view override returns (uint256[] memory) {
        return classes[classId].infos;
    }


    function nonceInfos(uint256 classId, uint256 nonceId) public view override returns (uint256[] memory) {
        return classes[classId].nonces[nonceId].infos;
    }

    function bondDetails(uint256 classId, uint256 nonceId) public view override returns (string memory _symbol, IData.InterestRateType _interestRateType, address _tokenAddress, uint256 _periodTimestamp, uint256 _issuanceDate, uint256 _maturityDate, uint256 _tokenLiquidity) {
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
        return bondsDue[tokenAddress][IData.InterestRateType.FloatingRate] + bondsDue[tokenAddress][IData.InterestRateType.FixedRate];
    }


    function classInfoDescription(uint256 classInfo) external view returns (string memory) {
        return classInfoDescriptions[classInfo];
    }

    function nonceInfoDescription(uint256 nonceInfo) external view returns (string memory) {
        return nonceInfoDescriptions[nonceInfo];
    }


    function isRedeemable(uint256 classId, uint256 nonceId) public override view returns (bool) {
        Class storage class = classes[classId];
        if (class.interestRateType == IData.InterestRateType.FixedRate) {
            return classes[classId].nonces[nonceId].maturityDate <= block.timestamp;
        }

        if (class.interestRateType == IData.InterestRateType.FloatingRate) {
            return true;
        }
        return false;

    }


    function allowance(address owner, address spender, uint256 classId, uint256 nonceId) external view returns (uint256) {
        return classes[classId].nonces[nonceId].allowances[owner][spender];
    }


    function isApprovedFor(address owner, address operator) public view virtual override returns (bool) {
        return operatorApprovals[owner][operator];
    }

    function bondAmountDue(address tokenAddress, IData.InterestRateType interestRateType) external view returns (uint256) {
        return bondsDue[tokenAddress][interestRateType];
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

    function _transferFrom(address from, address to, uint256 classId, uint256 nonceId, uint256 amount) private {
        require(from != address(0), "ERC3475: can't transfer from the zero address");
        require(to != address(0), "ERC3475: can't transfer to the zero address");
        require(classes[classId].nonces[nonceId].balances[from] >= amount, "ERC3475: not enough bond to transfer");
        _transfer(from, to, classId, nonceId, amount);
    }

    function _transfer(address from, address to, uint256 classId, uint256 nonceId, uint256 amount) private {
        require(from != to, "ERC3475: can't transfer to the same address");
        classes[classId].nonces[nonceId].balances[from] -= amount;
        classes[classId].nonces[nonceId].balances[to] += amount;
    }

    function _issue(address to, uint256 classId, uint256 nonceId, uint256 amount) private {
        classes[classId].nonces[nonceId].balances[to] += amount;
        classes[classId].nonces[nonceId]._activeSupply += amount;
    }

    function _redeem(address from, uint256 classId, uint256 nonceId, uint256 amount) private {
        require(classes[classId].nonces[nonceId].balances[from] >= amount);
        classes[classId].nonces[nonceId].balances[from] -= amount;
        classes[classId].nonces[nonceId]._activeSupply -= amount;
        classes[classId].nonces[nonceId]._redeemedSupply += amount;
    }

    function _burn(address from, uint256 classId, uint256 nonceId, uint256 amount) private {
        require(classes[classId].nonces[nonceId].balances[from] >= amount);
        classes[classId].nonces[nonceId].balances[from] -= amount;
        classes[classId].nonces[nonceId]._activeSupply -= amount;
        classes[classId].nonces[nonceId]._burnedSupply += amount;
    }
}
