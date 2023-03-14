// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidityPool {
    function emitTokenToInvestors(address _to, uint256 _amount) external;
    function receiveRepayments() external;

}