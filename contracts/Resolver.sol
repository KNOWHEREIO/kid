// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { KNSRegistry } from "./KNSRegistry.sol";
import { StringEnumerableMap } from "./libraries/StringEnumerableMap.sol";
import { IResolver } from "./interfaces/IResolver.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Resolver is IResolver,Ownable{

    using StringEnumerableMap for StringEnumerableMap.UintToStringMap;
    using EnumerableSet for EnumerableSet.UintSet; 
    KNSRegistry private registry;
    mapping(uint256 => mapping(uint256 => StringEnumerableMap.UintToStringMap)) private _domainMaps;
    mapping(uint256 => uint256) _domainContent;
    mapping(uint256 => mapping(uint256 => EnumerableSet.UintSet)) _hashedKeys;
    mapping(uint256 => uint256) _keyContent;
    mapping(uint256 => string) _keys;

    mapping(bytes32 => string) names;

    modifier onlyResolver(uint256 tokenId) {
        require(
            address(this) == registry.resolverOf(tokenId),
            "Resolver: resolver is not belong to the domain"
        );
        _;
    }

    modifier onlyApprovedOrOwner(uint256 tokenId) {
        require(
            registry.isApprovedOrOwner(msg.sender, tokenId),
            "Resolver: sender must be approved or owner"
        );
        _;
    }

    function setRegistry(KNSRegistry _registry) external onlyOwner{
        registry = _registry;
    }

    function makeDomainId(string memory label) public view returns(uint256){
        return registry.makeIdentity(registry.KID_ROOT_HASH(), label);
    }

    function makeSubDomainId(uint256 tokenId,string memory label) public view returns(uint256){
        return registry.makeIdentity(tokenId, label);
    }

    function allKeys(uint256 tokenId) external override view onlyResolver(tokenId) returns(string[] memory keys){
        uint256 length = _hashedKeys[tokenId][_keyContent[tokenId]].length();
        keys = new string[](length);
        for(uint i=0; i<length; i++){
            uint256 keyHash = _hashedKeys[tokenId][_keyContent[tokenId]].at(i);
            keys[i] = _keys[keyHash];
        }
    }

    function allRecords(uint256 tokenId) public override view onlyResolver(tokenId) returns(string[] memory keys,string[] memory values){
        uint256 length = _hashedKeys[tokenId][_keyContent[tokenId]].length();
        keys = new string[](length);
        values = new string[](length);
        for(uint i=0; i<length; i++){
            uint256 keyHash = _hashedKeys[tokenId][_keyContent[tokenId]].at(i);
            keys[i] = _keys[keyHash];
            values[i] = _get(tokenId, _keys[keyHash]);
        }
    }

    function _get(uint256 tokenId, string memory key) internal view returns (string memory) {
        return _domainMaps[tokenId][_domainContent[tokenId]].get(uint256(keccak256(bytes(key))));
    }

    function get(uint256 tokenId, string memory key)public override onlyResolver(tokenId) view returns (string memory){
        uint256 expiration = registry.timeHelper(tokenId);
        if(block.timestamp > expiration) return "";
        else return _get(tokenId, key);
    }

    function reset(uint256 tokenId) external override onlyApprovedOrOwner(tokenId){
        _domainContent[tokenId] = block.timestamp;
        emit ResetMapContent(tokenId, block.timestamp);
        _keyContent[tokenId] = block.timestamp;
        emit ResetKeyContent(tokenId, block.timestamp);
        // _domianForAddress[registry._tokenChars(tokenId)] = "";
    }

    function set(uint256 tokenId, string calldata key, string calldata value) external override onlyApprovedOrOwner(tokenId){
        _set(tokenId, key, value);
    }

    function _set(uint256 tokenId, string memory key, string memory value) internal {
        if (!(_domainContent[tokenId] > 0 && _keyContent[tokenId] > 0)) {
            _domainContent[tokenId] = block.timestamp;
            _keyContent[tokenId] = block.timestamp;
        }
        uint256 keyHash = uint256(keccak256(bytes(key)));
        bool _isNewKey = _domainMaps[tokenId][_domainContent[tokenId]].contains(keyHash);
        _domainMaps[tokenId][_domainContent[tokenId]].set(keyHash, value);
        _hashedKeys[tokenId][_keyContent[tokenId]].add(keyHash);

        if (bytes(_keys[keyHash]).length == 0) {
            _keys[keyHash] = key;
        }
        if (_isNewKey) {
            emit CreateKey(tokenId, key);
        }
        setName(tokenId, value);

        emit SetContent(tokenId, key, value);
    }

    function multiGet(uint256 tokenId,string[] memory keys) external override view onlyResolver(tokenId) returns(string[] memory values){
        return _multiGet(tokenId, keys);
    }

    function _multiGet(uint256 tokenId, string[] memory keys) internal view returns (string[] memory) {
        uint256 count = keys.length;
        string[] memory values = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            values[i] = _get(tokenId, keys[i]);
        }
        return values;
    }

    function multiSet(uint256 tokenId,string[] memory keys,string[] memory values) external override onlyApprovedOrOwner(tokenId){
        _multiSet(tokenId, keys, values);
    }

    function _multiSet(uint256 tokenId, string[] memory keys, string[] memory values) internal {
        uint256 count = keys.length;
        for (uint256 i = 0; i < count; i++) {
            _set(tokenId, keys[i], values[i]);
        }
    }

    function setName(uint256 tokenId,string memory addr) internal{
        bytes32 node = keccak256(abi.encodePacked(addr));
        names[node] = registry.tokenChars(tokenId);
        emit UpdateName(node, names[node]);
    }

    function getName(string calldata addr) external override view returns(string memory name){
        bytes32 node = keccak256(abi.encodePacked(addr));
        bool resolver = registry.timeHelper(registry.charsToId(keccak256(abi.encodePacked(names[node])))) > block.timestamp && _contain(addr);
        if(resolver) name = names[node];
    }

    function _contain(string memory addr) internal view returns(bool _isExist){
        bytes32 node = keccak256(abi.encodePacked(addr));
        uint256 tokenId = registry.charsToId(keccak256(abi.encodePacked(names[node])));
        (,string[] memory values) = allRecords(tokenId);
        for(uint i=0; i<values.length; i++){
            if(keccak256(bytes(values[i])) == keccak256(bytes(addr))){
                _isExist = true;
                break;
            }
        }
    }    
}