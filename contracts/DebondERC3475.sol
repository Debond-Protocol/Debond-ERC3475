// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2022 Debond Protocol <info@debond.org>
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

pragma solidity ^0.8.0;


import "./interfaces/IDebondBond.sol";
import "./interfaces/IProgressCalculator.sol";
import "./interfaces/ILiquidityRedeemable.sol";
import "@debond-protocol/debond-governance-contracts/utils/GovernanceOwnable.sol";


contract DebondERC3475 is IDebondBond, GovernanceOwnable {

    address bondManagerAddress;
    address redeemableAddress;

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
        uint256 classLiquidity;
        uint256 previousNonceIdCreated;
        mapping(uint256 => IERC3475.Values) values;
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
        mapping(uint256 => IERC3475.Values) values;
        mapping(uint256 => IERC3475.Metadata) nonceMetadatas;
        uint256[] nonceIds;
        mapping(uint256 => Nonce) nonces; // from nonceId given
        uint256 lastNonceIdCreated;
        uint256 lastNonceIdCreatedTimestamp;
    }

    mapping(uint256 => Class) internal classes; // from classId given
    mapping(uint256 => IERC3475.Metadata) classMetadatas;
    mapping(address => mapping(address => bool)) operatorApprovals;



    constructor(address _governanceAddress) GovernanceOwnable(_governanceAddress) {}

    modifier onlyBondManager() {
        require(msg.sender == bondManagerAddress, "DebondERC3475 Error: Not authorized");
        _;
    }

    /**
    * @notice change the Bank Address
    * @param _bondManagerAddress the new bondManagerAddress to set
    */
    function setBondManagerAddress(address _bondManagerAddress) onlyGovernance external {
        require(_bondManagerAddress != address(0), "DebondERC3475 Error: Address given is address(0)");
        bondManagerAddress = _bondManagerAddress;
    }

    /**
    * @notice change the Bank Address
    * @param _redeemableAddress the new bankAddress to set
    */
    function setRedeemableAddress(address _redeemableAddress) onlyGovernance external {
        require(_redeemableAddress != address(0), "DebondERC3475 Error: Address given is address(0)");
        redeemableAddress = _redeemableAddress;
    }


    // WRITE

    /**
    * @notice create a new metadata for classes on the actual bond contract
    * @param metadataId the identifier of the metadata being created
    * @param metadata the metadata to create
    */
    function createClassMetadata(uint metadataId, IERC3475.Metadata memory metadata) external onlyBondManager {
        classMetadatas[metadataId] = metadata;
    }

    /**
    * @notice create a new metadata for classes on the actual bond contract
    * @param metadataIds the identifiers of the metadatas being created
    * @param metadatas the metadatas to create
    */
    function createClassMetadataBatch(uint[] memory metadataIds, IERC3475.Metadata[] memory metadatas) external onlyBondManager {
        require(metadataIds.length == metadatas.length, "DebondERC3475: Incorrect inputs");
        for (uint i; i < metadataIds.length; i++) {
            classMetadatas[metadataIds[i]] = metadatas[i];
        }
    }


    /**
    * @notice create a new metadata for nonces for a given class
    * @dev if the classId given doesn't exist, will revert
    * @param classId the classId
    * @param metadataId the identifier of the metadata being created
    * @param metadata the metadata to create
    */
    function createNonceMetadata(uint classId, uint metadataId, IERC3475.Metadata memory metadata) external onlyBondManager {
        require(classExists(classId), "DebondERC3475: class Id not found");
        classes[classId].nonceMetadatas[metadataId] = metadata;
    }

    /**
    * @notice create metadatas for nonces for a given class
    * @dev if the classId given doesn't exist, will revert
    * @param classId the classId
    * @param metadataIds the identifiers of the metadatas being created
    * @param metadatas the metadatas to create
    */
    function createNonceMetadataBatch(uint classId, uint[] memory metadataIds, IERC3475.Metadata[] memory metadatas) external onlyBondManager {
        require(classExists(classId), "DebondERC3475: class Id not found");
        require(metadataIds.length == metadatas.length, "DebondERC3475: Incorrect inputs");
        for (uint i; i < metadataIds.length; i++) {
            classes[classId].nonceMetadatas[metadataIds[i]] = metadatas[i];
        }
    }


    /**
    * @notice issuance of bonds
    * @dev this method is a batch, if any error will revert and will not issue any bonds
    * @param to the address to issue bonds to
    * @param transactions represent the classIds, nonces and amounts that need to be issued
    */
    function issue(address to, Transaction[] calldata transactions) external override onlyBondManager {
        for (uint i; i < transactions.length; i++) {
            uint classId = transactions[i].classId;
            uint nonceId = transactions[i].nonceId;
            uint amount = transactions[i].amount;
            require(classes[classId].exists, "ERC3475: only issue bond that has been created");
            require(classes[classId].nonces[nonceId].exists, "ERC-3475: nonceId given not found!");
            require(to != address(0), "ERC3475: can't transfer to the zero address");
            _issue(to, classId, nonceId, amount);

            Class storage class = classes[classId];

            Nonce storage nonce = class.nonces[nonceId];
            nonce.classLiquidity += amount;
        }
        emit Issue(msg.sender, to, transactions);
    }

    /**
    * @notice creation of a new class
    * @dev metadatas and values length MUST match
    * @param classId identifier of the new class we want to create
    * @param metadataIds identifiers of the metadatas (keys for values)
    * @param values value collection
    */
    function createClass(uint256 classId, uint256[] calldata metadataIds, IERC3475.Values[] calldata values) external onlyBondManager {
        require(metadataIds.length == values.length, "ERC3475: inputs error");
        require(!classExists(classId), "ERC3475: cannot create a class that already exists");
        Class storage class = classes[classId];
        class.id = classId;
        class.exists = true;
        for (uint256 i; i < metadataIds.length; i++) {
            class.values[metadataIds[i]] = values[i];
        }
    }

    /**
    * @notice creation of a new nonce for a given class
    * @dev metadatas and values length MUST match
    * @param classId the classId of the class we want to create nonce on
    * @param nonceId identifier of the new nonce we want to create
    * @param metadataIds identifiers of the metadatas (keys for values)
    * @param values value collection
    */
    function createNonce(uint256 classId, uint256 nonceId, uint256[] calldata metadataIds, IERC3475.Values[] calldata values) external onlyBondManager {
        require(metadataIds.length == values.length, "ERC3475: inputs error");
        require(classExists(classId), "DebondERC3475: class Id not found");
        Class storage class = classes[classId];

        Nonce storage nonce = class.nonces[nonceId];
        require(!nonce.exists, "DebondERC3475: nonceId exists!");

        nonce.id = nonceId;
        nonce.exists = true;
        // we mark the new created nonce liquidity with the actual class liquidity
        nonce.classLiquidity = classLiquidity(classId);
        classes[classId].nonceIds.push(nonceId);
        for (uint256 i; i < metadataIds.length; i++) {
            class.nonces[nonceId].values[metadataIds[i]] = values[i];
        }
        // now we set the created nonceId as the new last nonceId created
        class.lastNonceIdCreated = nonceId;
        class.lastNonceIdCreatedTimestamp = block.timestamp;
    }

    /**
    * @notice transfer bonds (if u want to transfer via an approved spender with allowance, use "transferAllowanceFrom")
    * @param from address we transferring bonds from
    * @param to address we transferring bonds to
    * @param transactions classIds, nonceIds and amounts of transfers
    */
    function transferFrom(address from, address to, Transaction[] calldata transactions) external override {
        for (uint i; i < transactions.length; i++) {
            uint classId = transactions[i].classId;
            require(classExists(classId), "DebondERC3475: class Id not found");
            require(msg.sender == from || isApprovedFor(from, msg.sender), "DebondERC3475: caller is not owner nor approved");
            uint nonceId = transactions[i].nonceId;
            uint amount = transactions[i].amount;

            _transferFrom(from, to, classId, nonceId, amount);
        }

        emit Transfer(msg.sender, from, to, transactions);
    }

    /**
    * @notice transfer bonds with allowance from spender
    * @param from address we transferring bonds from
    * @param to address we transferring bonds to
    * @param transactions classIds, nonceIds and amounts of transfers
    */
    function transferAllowanceFrom(address from, address to, Transaction[] calldata transactions) external override {
        require(from != address(0), "DebondERC3475: can't transfer from the zero address");
        require(to != address(0), "DebondERC3475: can't transfer to the zero address");
        for (uint i; i < transactions.length; i++) {
            require(
                transactions[i].amount <= allowance(from, msg.sender, transactions[i].classId, transactions[i].nonceId),
                "DebondERC3475: caller has not enough allowance"
            );

            _transferFrom(from, to, transactions[i].classId, transactions[i].nonceId, transactions[i].amount);
        }

        emit Transfer(msg.sender, from, to, transactions);
    }

    /**
    * @notice redeem bonds
    * @param from address to redeem bonds from
    * @param _transactions IERC3475 transaction collection
    */
    function redeem(address from, Transaction[] calldata _transactions) external override {
        for (uint i; i < _transactions.length; i++) {
            uint classId = _transactions[i].classId;
            uint nonceId = _transactions[i].nonceId;
            uint amount = _transactions[i].amount;
            require(classes[classId].nonces[nonceId].exists, "ERC3475: given Nonce doesn't exist");
            require(from != address(0), "ERC3475: can't transfer to the zero address");
            (, uint256 progressRemaining) = getProgress(classId, nonceId);
            require(progressRemaining == 0, "Bond is not redeemable");
            _redeem(from, classId, nonceId, amount);
        }
        // liquidity backing the bonds transfers
        ILiquidityRedeemable(redeemableAddress).redeemLiquidity(from, _transactions);
        emit Redeem(msg.sender, from, _transactions);
    }

    /**
    * @notice burn bonds
    * @param from address to burn bonds from
    * @param transactions classIds, nonceIds and amounts
    */
    function burn(address from, Transaction[] calldata transactions) external override onlyBondManager {
        require(from != address(0), "ERC3475: can't transfer to the zero address");
        for (uint i; i < transactions.length; i++) {
            require(msg.sender == from || isApprovedFor(from, msg.sender), "ERC3475: caller is not owner nor approved");
            _burn(from, transactions[i].classId, transactions[i].nonceId, transactions[i].amount);
        }
        emit Burn(msg.sender, from, transactions);
    }

    /**
    * @param spender address to approve
    * @param transactions classIds, nonceIds and amounts
    */
    function approve(address spender, Transaction[] calldata transactions) external override {
        for (uint i; i < transactions.length; i++) {
            classes[transactions[i].classId].nonces[transactions[i].nonceId].allowances[msg.sender][spender] = transactions[i].amount;
        }
    }

    /**
    * @param operator address to set approval for
    * @param approved true => approved, false => unapproved
    */
    function setApprovalFor(address operator, bool approved) external override {
        operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalFor(msg.sender, operator, approved);
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

    // READS

    function getProgress(uint256 classId, uint256 nonceId) public view returns (uint256 progressAchieved, uint256 progressRemaining) {
        return IProgressCalculator(bondManagerAddress).getProgress(classId, nonceId);
    }

    function getLastNonceCreated(uint classId) external view returns (uint nonceId, uint createdAt) {
        Class storage class = classes[classId];
        require(class.exists, "Debond Data: class id given not found");
        nonceId = class.lastNonceIdCreated;
        createdAt = class.lastNonceIdCreatedTimestamp;
        return (nonceId, createdAt);
    }

    function classExists(uint256 classId) public view returns (bool) {
        return classes[classId].exists;
    }

    function nonceExists(uint256 classId, uint256 nonceId) public view returns (bool) {
        return classes[classId].nonces[nonceId].exists;
    }

    function classLiquidity(uint256 classId) public view returns (uint256) {
        return classes[classId].nonces[classes[classId].lastNonceIdCreated].classLiquidity;
    }

    function classLiquidityBatch(uint256[] calldata classIds) external view returns (uint256[] memory) {
        uint256[] memory liquidities = new uint[](classIds.length);
        for(uint i; i < classIds.length; i++) {
            liquidities[i] = classLiquidity(classIds[i]);
        }
        return liquidities;
    }

    function classLiquidityAtNonce(uint256 classId, uint256 nonceId, uint256 searchNonceLimit) external view returns (uint256) {
        // if class has no liquidity it means no liquidity on any nonce
        if(classLiquidity(classId) == 0) {
            return 0;
        }
        // we check if the nonceId given is greater than the last nonce Issued
        uint lastNonce = classes[classId].lastNonceIdCreated;
        if(nonceId > lastNonce) {
            return classes[classId].nonces[lastNonce].classLiquidity;
        }

        if(!nonceExists(classId, nonceId)) {
            while(!nonceExists(classId, nonceId) && nonceId > searchNonceLimit) {
                --nonceId;
            }
        }
        return classes[classId].nonces[nonceId].classLiquidity;
    }

    function totalSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return
        classes[classId].nonces[nonceId]._activeSupply +
        classes[classId].nonces[nonceId]._redeemedSupply +
        classes[classId].nonces[nonceId]._burnedSupply;

    }

    function activeSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return classes[classId].nonces[nonceId]._activeSupply;
    }

    function burnedSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return classes[classId].nonces[nonceId]._burnedSupply;
    }

    function redeemedSupply(uint256 classId, uint256 nonceId) public override view returns (uint256) {
        return classes[classId].nonces[nonceId]._redeemedSupply;
    }

    function balanceOf(address account, uint256 classId, uint256 nonceId) public override view returns (uint256) {
        require(account != address(0), "ERC3475: balance query for the zero address");

        return classes[classId].nonces[nonceId].balances[account];
    }

    function classValues(uint256 classId, uint256 metadataId) public view override returns (IERC3475.Values memory) {
        return classes[classId].values[metadataId];
    }

    function nonceValues(uint256 classId, uint256 nonceId, uint256 metadataId) public view override returns (IERC3475.Values memory) {
        return classes[classId].nonces[nonceId].values[metadataId];
    }

    function classMetadata(uint256 metadataId) external view returns (Metadata memory) {
        return classMetadatas[metadataId];
    }

    function nonceMetadata(uint256 classId, uint256 metadataId) external view returns (Metadata memory) {
        return classes[classId].nonceMetadatas[metadataId];
    }

    function allowance(address owner, address spender, uint256 classId, uint256 nonceId) public view returns (uint256) {
        return classes[classId].nonces[nonceId].allowances[owner][spender];
    }

    function isApprovedFor(address owner, address operator) public view override returns (bool) {
        return operatorApprovals[owner][operator];
    }
}
