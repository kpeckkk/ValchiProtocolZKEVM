// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManager {
    function getAddress(uint256 _key) external view returns (address);
    function getLeverage() external view returns (uint256);
    function getUnderwriterFee() external view returns (uint256);
    function getPerformanceFee() external view returns (uint256);
    function getDefaultReserveRatio() external view returns (uint256);
}