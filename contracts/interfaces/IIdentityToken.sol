// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIdentityToken {
    function getWhitelisted (address _user) external view returns (bool);
}