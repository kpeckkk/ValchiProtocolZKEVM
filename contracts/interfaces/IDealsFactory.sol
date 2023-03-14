// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDealsFactory {
    function getDealState (address _dealContract) external view returns (bool);
    function getDealByIndex (uint256 _i) external view returns (address);
}