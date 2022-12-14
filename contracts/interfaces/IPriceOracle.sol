// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceOracle{
    function getPrice(string calldata label,uint expiration) external view returns(uint);
}