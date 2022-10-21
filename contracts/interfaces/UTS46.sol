// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract UTS46{

    //0x4142434445464748494a4b4c4d4e4f505152535455565758595a6162636465666768696a6b6c6d6e6f707172737475767778797a

    function _getSupport(bytes memory content) internal pure returns(bool support){
        uint j;
        for(uint i=0; i<content.length; i++){
            if(!_getSupportSingle(bytes1(content[i]))) j++;
        }
        if(j == 0) support = true;
    }

    function _getSupportSingle(bytes1 value) internal pure returns(bool support){
        bool _letter = value >= 0x61 && value <= 0x7a;
        bool _num = value >= 0x30 && value <= 0x39;
        bool _separate = value == 0x2d || value == 0x5f;
        if(_num || _letter || _separate) support = true;
    }

    function _getCodeResult(bytes memory table,string memory value) internal pure returns(bytes memory){
        bytes memory valueHash = bytes(value);
        bytes memory result = new bytes(valueHash.length);
        for(uint i=0; i<valueHash.length; i++){
            if(bytes1(valueHash[i]) >= 0x41 && bytes1(valueHash[i]) <= 0x5a) result[i] = _replace(table,valueHash[i]);
            else result[i] = valueHash[i];
        }
        return result;
    }

    function _replace(bytes memory table,bytes1 value) internal pure returns(bytes1 char){
        for(uint i=0; i<table.length/2; i++){
            if(table[i] == value) char = table[i+table.length/2];
        }
    }

}