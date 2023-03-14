// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

//inserire le get in manager

contract Manager is Ownable{
    
    //mapping user - credit scores
    mapping (uint256 => address) private router;
    //list of addressess of protocol smart contracts
    // 1 => IdentityToken
    // 2 => DealsFactory
    // 3 => InvestorsRouter
    // 4 => LiquidityPool
    // 5 => ConversionPool
    uint256 private leverage; // from 0 to 100 -> 0 equal to only interest allocated to liquidity providing, 100 equals to only interest allocated to deals underwriting
    uint256 private underwriterFee; // minimun % of interest that goes always to the underwriters
    uint256 private performanceFee; // % of interest that goes always to to Valchi protocol
    uint256 private defaultReserveRatio; // % of interest fee that goes always to the default reserve

    

    /**
     * @dev set the address of a contract
     * @param _key key of the address in the mapping
     * @param _contract address of the contract we need
     **/
    function setAddress(uint256 _key, address _contract) public onlyOwner {
        router[_key] = _contract;
    }
    
    /**
     * @dev return the address of the protocols contract 
     * @param _key key of the address in the mapping
     **/
    function getAddress(uint256 _key) public view returns (address) {
        return router[_key];
    }

    /**
     * @dev set the leverage
     * @param _leverage leverage formula for senior and junior interest
     **/
    function setLeverage (uint256 _leverage) onlyOwner public {
        require(_leverage<=100 && _leverage >= 0, "The leverage is not betweeen 0 and 100");
        leverage = _leverage;
    }

    /**
     * @dev return the leverage parameter
     **/
    function getLeverage() public view returns (uint256) {
        return leverage;
    }

    /**
     * @dev set the underwriter fee
     * @param _underwriterFee base fee for underwriting a deal
     **/
    function setUnderwriterFee (uint256 _underwriterFee) onlyOwner public {
        require(_underwriterFee<=100 && _underwriterFee >= 0, "The underwriter fee % is not betweeen 0 and 100");
        underwriterFee = _underwriterFee;
    }

    /**
     * @dev return the underwrite fee parameter
     **/
    function getUnderwriterFee() public view returns (uint256) {
        return underwriterFee;
    }

    /**
     * @dev set the performance fee
     * @param _performanceFee fees that goes to Valchi protocol
     **/
    function setPerformanceFee (uint256 _performanceFee) onlyOwner public {
        require(_performanceFee<=100 && _performanceFee >= 0, "The performance fee % is not betweeen 0 and 100");
        performanceFee = _performanceFee;
    }

    /**
     * @dev return the performance fee parameter
     **/
    function getPerformanceFee() public view returns (uint256) {
        return performanceFee;
    }

    /**
     * @dev set the defaultReserveRatio
     * @param _defaultReserveRatio fees that goes to the default reserve
     **/
    function setDefaultReserveRatio (uint256 _defaultReserveRatio) onlyOwner public {
        require(_defaultReserveRatio<=100 && _defaultReserveRatio >= 0, "The default reserve ratio is not betweeen 0 and 100");
        defaultReserveRatio = _defaultReserveRatio;
    }

    /**
     * @dev return the default reserve ratio parameter
     **/
    function getDefaultReserveRatio() public view returns (uint256) {
        return defaultReserveRatio;
    }

   

}