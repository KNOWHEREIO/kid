// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IResolver{

    event CreateKey(uint256 indexed tokenId,string key);
    event ResetMapContent(uint256 indexed tokenId,uint256 indexed mapContentId);
    event ResetKeyContent(uint256 indexed tokenId,uint256 indexed keyContentId);
    event SetContent(uint256 indexed tokenId,string key,string value);
    event UpdateName(bytes32 addrNode,string name);

    function allKeys(uint256 tokenId) external view returns(string[] memory keys);

    function allRecords(uint256 tokenId) external view returns(string[] memory keys,string[] memory values);

    function get(uint256 tokenId, string memory key)external view returns (string memory);

    function reset(uint256 tokenId) external;

    function set(uint256 tokenId, string calldata key, string calldata value) external;

    function multiGet(uint256 tokenId,string[] memory keys) external view returns(string[] memory values);

    function multiSet(uint256 tokenId,string[] memory keys,string[] memory values) external;

    function getName(string calldata addr) external view returns(string memory name);
}