// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Domain } from "../libraries/Domain.sol";

interface IKNSRegistry{
    
    event CreateDomain(uint256 indexed tokenId,string domainChars,uint256 expiration,uint256 totalExpiration,uint payType);
    event UpdateResolver(uint256 indexed tokenId,address resolver);
   
    event Renew(uint256 indexed tokenId,uint256 expiration,uint256 totalExpiration,uint payType);

   
    function isExist(uint256 tokenId,string memory label) external view returns(bool);

    function makeIdentity(uint256 tokenId,string memory label) external  view returns(uint256);

    function isApprovedOrOwner(address account, uint256 tokenId) external view returns(bool);

    function safeMintDomain(Domain.DomainContent calldata content) external payable;

    function transferDomain(address from,address to,string calldata label) external;

    function safeTransferDomain(address from, address to, string calldata label, bytes calldata data) external;

    function transferSubDomain(address from, address to, string calldata label, string calldata subLabel) external;

    function safeTransferSubDomain(
        address from, 
        address to, 
        string calldata label, 
        string calldata subLabel, 
        bytes calldata _data) external;

    function resolverOf(uint256 tokenId) external view returns (address);

    function setResolver(uint256 tokenId,address resolver) external;

    function burnSubDomain(uint256 tokenId,string calldata label) external;

    function renewalDomain(string calldata label,uint256 expiration) external payable;

    function renewalDomainForWhitelisted(Domain.Renew calldata renew) external ;
}