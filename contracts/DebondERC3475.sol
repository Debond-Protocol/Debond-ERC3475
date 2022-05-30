// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;


import "erc3475/contracts/IERC3475.sol";
import "./interfaces/IDebondBond.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";



abstract contract DebondERC3475 is IERC3475, AccessControl {

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
        uint256 classLiquidity;
        uint256[] infos;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
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
        IDebondBond.InterestRateType interestRateType;
        address tokenAddress;
        uint256 periodTimestamp;
        uint256 liquidity;
        mapping(address => mapping(uint256 => bool)) noncesPerAddress;
        mapping(address => uint256[]) noncesPerAddressArray;
        mapping(address => mapping(address => bool)) operatorApprovals;
        uint256[] nonceIds;
        mapping(uint256 => Nonce) nonces; // from nonceId given
        uint256 lastNonceIdCreated;
        uint256 lastNonceIdCreatedTimestamp;
    }

    mapping(uint256 => Class) internal classes; // from classId given
    string[] public classInfoDescriptions; // mapping with class.infos
    string[] public nonceInfoDescriptions; // mapping with nonce.infos
    mapping(address => mapping(uint256 => bool)) classesPerHolder;
    mapping(address => uint256[]) public classesPerHolderArray;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


    // WRITE

    function transferFrom(address from, address to, uint256 classId, uint256 nonceId, uint256 amount) public virtual override {
        require(msg.sender == from || isApprovedFor(from, msg.sender, classId), "ERC3475: caller is not owner nor approved");
        _transferFrom(from, to, classId, nonceId, amount);
        emit Transfer(msg.sender, from, to, classId, nonceId, amount);
    }



    function redeem(address from, uint256 classId, uint256 nonceId, uint256 amount) external override onlyRole(ISSUER_ROLE) {
        require(classes[classId].nonces[nonceId].exists, "ERC3475: given Nonce doesn't exist");
        require(from != address(0), "ERC3475: can't transfer to the zero address");
        require(isRedeemable(classId, nonceId), "Bond is not redeemable");
        _redeem(from, classId, nonceId, amount);
        emit Redeem(msg.sender, from, classId, nonceId, amount);
    }


    function burn(address from, uint256 classId, uint256 nonceId, uint256 amount) external override onlyRole(ISSUER_ROLE) {
        require(from != address(0), "ERC3475: can't transfer to the zero address");
        _burn(from, classId, nonceId, amount);
        emit Burn(msg.sender, from, classId, nonceId, amount);
    }


    function approve(address spender, uint256 classId, uint256 nonceId, uint256 amount) external override {
        classes[classId].nonces[nonceId].allowances[msg.sender][spender] = amount;
    }


    function setApprovalFor(address operator, uint256 classId, bool approved) public override {
        classes[classId].operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalFor(msg.sender, operator, classId, approved);
    }


    function batchApprove(address spender, uint256[] calldata classIds, uint256[] calldata nonceIds, uint256[] calldata amounts) external {
        require(classIds.length == nonceIds.length && classIds.length == amounts.length, "ERC3475 Input Error");
        for (uint256 i = 0; i < classIds.length; i++) {
            classes[classIds[i]].nonces[nonceIds[i]].allowances[msg.sender][spender] = amounts[i];
        }
    }

    // READS


    function totalSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return classes[classId].nonces[nonceId]._activeSupply + classes[classId].nonces[nonceId]._redeemedSupply;
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

    function classInfoDescription(uint256 classInfo) external view returns (string memory) {
        return classInfoDescriptions[classInfo];
    }

    function nonceInfoDescription(uint256 nonceInfo) external view returns (string memory) {
        return nonceInfoDescriptions[nonceInfo];
    }


    function isRedeemable(uint256 classId, uint256 nonceId) public virtual override view returns (bool);

    function allowance(address owner, address spender, uint256 classId, uint256 nonceId) external view returns (uint256) {
        return classes[classId].nonces[nonceId].allowances[owner][spender];
    }


    function isApprovedFor(address owner, address operator, uint256 classId) public view virtual override returns (bool) {
        return classes[classId].operatorApprovals[owner][operator];
    }

    function _transferFrom(address from, address to, uint256 classId, uint256 nonceId, uint256 amount) internal {
        require(from != address(0), "ERC3475: can't transfer from the zero address");
        require(to != address(0), "ERC3475: can't transfer to the zero address");
        require(classes[classId].nonces[nonceId].balances[from] >= amount, "ERC3475: not enough bond to transfer");
        _transfer(from, to, classId, nonceId, amount);
    }

    function _transfer(address from, address to, uint256 classId, uint256 nonceId, uint256 amount) internal {
        require(from != to, "ERC3475: can't transfer to the same address");
        classes[classId].nonces[nonceId].balances[from] -= amount;
        classes[classId].nonces[nonceId].balances[to] += amount;
    }

    function _issue(address to, uint256 classId, uint256 nonceId, uint256 amount) internal {
        classes[classId].nonces[nonceId].balances[to] += amount;
        classes[classId].nonces[nonceId]._activeSupply += amount;
    }

    function _redeem(address from, uint256 classId, uint256 nonceId, uint256 amount) internal {
        require(classes[classId].nonces[nonceId].balances[from] >= amount);
        classes[classId].nonces[nonceId].balances[from] -= amount;
        classes[classId].nonces[nonceId]._activeSupply -= amount;
        classes[classId].nonces[nonceId]._redeemedSupply += amount;
    }

    function _burn(address from, uint256 classId, uint256 nonceId, uint256 amount) internal {
        require(classes[classId].nonces[nonceId].balances[from] >= amount);
        classes[classId].nonces[nonceId].balances[from] -= amount;
        classes[classId].nonces[nonceId]._activeSupply -= amount;
        classes[classId].nonces[nonceId]._burnedSupply += amount;
    }
}
