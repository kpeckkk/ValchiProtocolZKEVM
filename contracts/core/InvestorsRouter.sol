// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//openzeppelin
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

//protocols contracts
import { IIdentityToken } from "../interfaces/IIdentityToken.sol";
import { IManager } from "../interfaces/IManager.sol";
import { IDealsFactory } from "../interfaces/IDealsFactory.sol";
import { ILiquidityPool } from "../interfaces/ILiquidityPool.sol";

//the ERC20 contract for deal's tokens
import { Deal } from "../core/Deal.sol";


contract InvestorsRouter is Ownable {

    ERC20 private DAI;
   
    IIdentityToken private identityToken;
    IManager private manager;
    IDealsFactory private dealsFactory;
    ILiquidityPool private liquidityPool;

    constructor(bytes memory _encodedAddresses)  {
        
        //set the contracts interfaces     
        address _managerAddress;
        address _DAIAddress;
        
        (_managerAddress, _DAIAddress) = abi.decode(_encodedAddresses,(address,address));
        manager = IManager(_managerAddress);
        DAI = ERC20(_DAIAddress);
        identityToken = IIdentityToken(manager.getAddress(1));
        dealsFactory = IDealsFactory(manager.getAddress(2));

       
    }

    function setLiquidityPool () public onlyOwner{
        liquidityPool = ILiquidityPool(manager.getAddress(4));
    }
    
    /**
     * @dev underwriter investment
     * @param _deal the deal address
     * @param _amount to amount to invest 
    **/
    function investInDeals (address _investor, address _deal, uint256 _amount) public {
        require(_investor == msg.sender || msg.sender == owner(), "You are not whitelisted for invest in this asset");
        require(identityToken.getWhitelisted(_investor)==true , "You are not whitelisted for invest in this asset");
        DAI.transferFrom(_investor,_deal,_amount);
        Deal(_deal).emitTokensToInvestors(_investor, _amount);
    }

    /**
     * @dev liquidity provider investment
     * @param _amount the amount to invest
    **/
    function investInLiquidityPool (address _investor, uint256 _amount) public {
        require(_investor == msg.sender || msg.sender == owner(), "You are not whitelisted for invest in this asset");
        require(identityToken.getWhitelisted(_investor)==true , "You are not whitelisted for invest in this asset");
        DAI.transferFrom(_investor,address(liquidityPool),_amount);
        liquidityPool.emitTokenToInvestors(_investor, _amount);
    }
    
}