// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//openzeppelin
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

//protocols contracts
import { IIdentityToken } from "../interfaces/IIdentityToken.sol";
import { IManager } from "../interfaces/IManager.sol";
import { IInvestorsRouter } from "../interfaces/IInvestorsRouter.sol";
import { IDealsFactory } from "../interfaces/IDealsFactory.sol";
import { Deal } from "../core/Deal.sol";



contract ConversionPool is ERC20{


    IIdentityToken private identityToken;
    IManager private manager;
    IInvestorsRouter private investorsRouter;
    IDealsFactory private dealsFactory;

    using Counters for Counters.Counter;
    Counters.Counter private _investorsCounter;
    
    mapping (address => uint256) deals;
    uint256 totalPrincipal;
    uint256 totalInterests;
    uint256 amountToInvest;

    mapping (address => uint256) holdersRedeems;
    uint256 aprPool;


    constructor(bytes memory _encodedAddresses) ERC20("PerpetualToken", "PTK") {
         //set the contracts interfaces     
        address _managerAddress;
        address _bentoboxAddress; 
        address _masterContractManagerBentoboxAddress;  
        (_managerAddress, _bentoboxAddress, _masterContractManagerBentoboxAddress) = abi.decode(_encodedAddresses,(address,address,address));
        manager = IManager(_managerAddress);
    
        identityToken = IIdentityToken(manager.getAddress(1));
        dealsFactory = IDealsFactory(manager.getAddress(2));
        investorsRouter = IInvestorsRouter(manager.getAddress(3));

        totalPrincipal = 0;
        totalInterests = 0;
        amountToInvest = 0;
        aprPool = 0;
    }

    /**
     * @dev hook for implement a limited trasfearable token only between KYC users
     * @param _from the sender
     * @param _to the receiver
     * @param _amount the amount of ERC20
    **/
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount)
        internal override virtual 
    {
        super._beforeTokenTransfer(_from, _to, _amount);
        require(identityToken.getWhitelisted(_to) == true, "The receiver is not whitelisted");
        holdersRedeems[_to] = block.timestamp;
    }

    function changeTokens(uint256 _amount, address _deal) public {
        //check the existence of the tokens deal
        require(dealsFactory.getDealState(_deal),"the deal does not exist or is closed");
        //transfer the tokens in this contract
        ERC20(Deal(_deal).getERC20address()).transferFrom(msg.sender,address(this),_amount);
        //emit new perpetual bonds tokens
        _mint(msg.sender, _amount);
        totalPrincipal = totalPrincipal + _amount;
        deals[_deal]=_amount;
        holdersRedeems[msg.sender] = block.timestamp;

        //TD modify APR pool
    }


    function receiveRepayments(uint256 _amount) public {
        //check the caller is a deal
        require(dealsFactory.getDealState(msg.sender), "This deal contract does not exist");
        //reinvest the funds in another deal
        if(_amount > deals[msg.sender]){
            totalInterests = totalInterests + _amount - deals[msg.sender];
            deals[msg.sender] = 0;
        }
        else{
            deals[msg.sender] = deals[msg.sender] - _amount;
        }
        reinvest(_amount);
    }

    function reinvest (uint256 _amount) internal {
        amountToInvest = amountToInvest + _amount;
        uint i = 0;
        while (amountToInvest>0 && dealsFactory.getDealByIndex(i) != address(this)){ //to modify with address null
                if(dealsFactory.getDealState(dealsFactory.getDealByIndex(i))){
                    uint256 juniorInvested = Deal(dealsFactory.getDealByIndex(i)).emitTokensToInvestors(address(this), amountToInvest);
                    amountToInvest = amountToInvest - juniorInvested;
                    //TD modify APR pool
                }
            }
        
    }
    
    //called by token holders
    function redeemInterests() public {
        require(balanceOf(msg.sender)>0, "you have no perpetual bonds");
        uint256 interests = balanceOf(msg.sender) * aprPool * ((block.timestamp - holdersRedeems[msg.sender])/365);
        transfer(msg.sender,interests);
        holdersRedeems[msg.sender] = block.timestamp;
    }


}