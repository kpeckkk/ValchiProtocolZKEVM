// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

import { Deal } from "../core/Deal.sol";
import { IIdentityToken } from "../interfaces/IIdentityToken.sol";
import { IManager } from "../interfaces/IManager.sol";

contract DealsFactory is Ownable{

    IManager private manager;
    IIdentityToken private identityToken;

    using Counters for Counters.Counter;
    Counters.Counter private _dealsCounter;

    Deal private DealContract;

    bytes private encodedAddresses; // Manager - StableCoin - Bentobox - MasterContractBentobox
    mapping (uint256 => address) private dealsListByIndex; //dealsList for a better research on the list
    mapping (address => bool) private dealsList; //dealsList with their state: true = active, false = inactive
   
   constructor (bytes memory _encodedAddresses) {
        address _managerAddress;
        
        encodedAddresses = _encodedAddresses;
        (_managerAddress,,,) = abi.decode(_encodedAddresses,(address,address,address,address));
        manager = IManager(_managerAddress);
        identityToken = IIdentityToken(manager.getAddress(1));
    }

    /**
     * @dev called by the governance for modify the addresses of the contracts of the protocol
     * @param _newEncodedContracts the new addresses of the protocol contract
    **/
    function modifyEncodedAddresses (bytes memory _newEncodedContracts) onlyOwner public {
        address _managerAddress;
        
        encodedAddresses = _newEncodedContracts;
        (_managerAddress,,,) = abi.decode(_newEncodedContracts,(address,address,address,address));
        manager = IManager(_managerAddress);
        identityToken = IIdentityToken(manager.getAddress(1));
    }


    /**
     * @dev called by the originator which wants to create a new deal
     * @param _encodedLoanData the main variables of the loan in the deal
    **/
    function createDeal (bytes memory _encodedLoanData) public returns (address) {
        //check KYB
        //require(identityToken.getWhitelisted(msg.sender) == true);

        //create deal contract
        DealContract = new Deal(encodedAddresses, _encodedLoanData);
        //add to the list
        dealsListByIndex[_dealsCounter.current()] = address(DealContract);
        dealsList[address(DealContract)] = true;
        _dealsCounter.increment();
        return address(DealContract);
    }

    /**
     * @dev return the deal contract selected state
     * @param _dealContract address of the deal contract
    **/
    function getDealState (address _dealContract) public view returns (bool){
        return dealsList[_dealContract];
    }

    /**
     * @dev return the deal contract address
     * @param _i index of the deal in the factory
    **/
    function getDealByIndex (uint256 _i) public view returns (address){
        return dealsListByIndex[_i];
    }

    /**
     * @dev called from the governance for distribute repayments of a deal to underwriters
     * @param _dealContract address of the deal contract
     * @param _id identifier of the investor in the loan
    **/
    function distributeFundsJunior (address _dealContract, uint256 _id) public onlyOwner {
        Deal(_dealContract).distributeRepaymentsJunior(_id);
    }

}