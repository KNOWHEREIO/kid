// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library Domain{

    bytes32 constant CONTENT_HASH = 0x6e998b52b58db520931ab5f3b102451eb5a5c12756799fb4a59a0f5237b45f5d;
    bytes32 constant RENEW_HASH = 0x9bd2b0b43ff2c279d38e8d9ae3b05d24eccdff45bdf9a745c11a2eb8e7f15705;

    struct DomainContent{
        uint256 tokenId;
        string  label;
        uint256 expiration; 
        address holder;
        bool    whitelisted;
        bytes   data;
        uint8 v; // v: parameter (27 or 28)
        bytes32 r; // r: parameter
        bytes32 s;
    }

    struct Renew{
        string  label;
        uint256 expiration;//min Time = 365
        uint8 v; // v: parameter (27 or 28)
        bytes32 r; // r: parameter
        bytes32 s;
    }

    function getDomainHash(DomainContent calldata content) internal pure returns(bytes32){
        return keccak256(abi.encode(
            CONTENT_HASH,
            content.tokenId,
            keccak256(bytes(content.label)),
            content.expiration,
            content.holder,
            content.whitelisted,
            keccak256(content.data)));
    }

    function getRenewHash(Renew calldata renew) internal pure returns(bytes32){
        return keccak256(abi.encode(
            RENEW_HASH,
            keccak256(bytes(renew.label)),
            renew.expiration
        ));
    }

    
    
}