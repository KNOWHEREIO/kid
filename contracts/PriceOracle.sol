// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StringUtil} from "./libraries/StringUtil.sol";


contract PriceOracle is IPriceOracle,Ownable{

    uint256 fourChars = 5e16;
    uint256 fiveCharsPlus = 1e16;

    function updateFeeRate(uint256 _fourChars,uint256 _fiveCharsPlus) external onlyOwner{
        fourChars = _fourChars;
        fiveCharsPlus = _fiveCharsPlus;
    }

    function getPrice(string calldata label,uint expiration) external override view returns(uint){
        uint256 length = StringUtil.strlen(label);
        if(length == 4) return fourChars / 365 * expiration;
        else if(length >= 5) return fiveCharsPlus / 365 * expiration;
        else return 0;
    }


}