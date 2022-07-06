pragma solidity ^0.8.0;


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

import "erc3475/IERC3475.sol";



interface IDebondBond is IERC3475{

    function createClassMetadata(uint metadataId, IERC3475.Metadata memory metadata) external;

    function createClassMetadataBatch(uint[] memory metadataIds, IERC3475.Metadata[] memory metadatas) external;

    function createNonceMetadata(uint classId, uint metadataId, IERC3475.Metadata memory metadata) external;

    function createNonceMetadataBatch(uint classId, uint[] memory metadataIds, IERC3475.Metadata[] memory metadatas) external;

    function createNonce(uint256 classId, uint256 nonceId, uint256[] calldata metadataIds, IERC3475.Values[] calldata values) external;

    function createClass(uint256 classId, uint256[] calldata metadataIds, IERC3475.Values[] calldata values) external;

    function updateLastNonce(uint classId, uint nonceId, uint createdAt) external;

    function getLastNonceCreated(uint classId) external view returns(uint nonceId, uint createdAt);

    function classExists(uint256 classId) external view returns (bool);

    function nonceExists(uint256 classId, uint256 nonceId) external view returns (bool);

    function classLiquidity(uint256 classId) external view returns (uint256);

    function classLiquidityAtNonce(uint256 classId, uint256 nonceId) external view returns (uint256);
}

