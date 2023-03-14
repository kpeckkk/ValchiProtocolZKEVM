// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConversionPool {
    function receiveRepayments(uint256 _amount) external;
}