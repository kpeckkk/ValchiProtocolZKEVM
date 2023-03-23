// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//openzeppelin
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

//protocols contracts
import { IIdentityToken } from "../interfaces/IIdentityToken.sol";
import { IManager } from "../interfaces/IManager.sol";
import { IInvestorsRouter } from "../interfaces/IInvestorsRouter.sol";
import { IDealsFactory } from "../interfaces/IDealsFactory.sol";
import { Deal } from "../core/Deal.sol";

//bentobox contracts
import { IBentobox } from "../interfaces/Bentobox/IBentobox.sol";
import { IMasterContractManager } from "../interfaces/Bentobox/IMasterContractManager.sol";

contract ConversionPool is ERC20, Ownable{

    IBentobox private bentobox;
    IMasterContractManager private masterContractManagerBentobox;

    IIdentityToken private identityToken;
    IManager private manager;
    IInvestorsRouter private investorsRouter;
    IDealsFactory private dealsFactory;
    ERC20 private DAI;

    using Counters for Counters.Counter;
    Counters.Counter private _investorsCounter;
    
    mapping (address => uint256) deals;
    uint256 totalPrincipal;
    uint256 totalInterests;
    uint256 amountToInvest;
    uint256 totalMarketMakersFee;

    mapping (address => uint256) holdersRedeems;
    mapping (address => uint256) marketMakersRedeems;
    mapping (address => uint256) marketMakersTimings;
    uint256 aprPool;
    uint256 marketmakersFee;
    uint256 marketmakersRedeemTime;


    constructor(bytes memory _encodedAddresses, uint256 _marketMakersFee, uint256 _marketmakersRedeemTime) ERC20("PerpetualToken", "PTK") {
         //set the contracts interfaces     
        address _managerAddress;
        address _DAIAddress;
        address _bentoboxAddress; 
        address _masterContractManagerBentoboxAddress;  
        (_managerAddress, _DAIAddress, _bentoboxAddress, _masterContractManagerBentoboxAddress) = abi.decode(_encodedAddresses,(address,address,address,address));
        manager = IManager(_managerAddress);
        bentobox = IBentobox(_bentoboxAddress);
        masterContractManagerBentobox = IMasterContractManager(_masterContractManagerBentoboxAddress);
        identityToken = IIdentityToken(manager.getAddress(1));
        dealsFactory = IDealsFactory(manager.getAddress(2));
        investorsRouter = IInvestorsRouter(manager.getAddress(3));
        DAI = ERC20(_DAIAddress);

        totalPrincipal = 0;
        totalInterests = 0;
        amountToInvest = 0;
        aprPool = 0;

        marketmakersFee=_marketMakersFee;
        marketmakersRedeemTime = _marketmakersRedeemTime;
    }

    /**
     * @dev Set the approval on this contract for operate on behalf of the user
     * @param user the originator address
     * @param approved to approve the contract = true
     * @param v signature of the originator
     * @param r signature of the originator
     * @param s signature of the originator
    **/
    function setBentoBoxApproval(
        address user,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyOwner {
        masterContractManagerBentobox.setMasterContractApproval(
            user,
            address(this),
            approved,
            v,
            r,
            s
        );
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

    /**
     * @dev change deals tokens for perpetual bonds
     * @param _amount the amount of the deal tokens to change
     * @param _deal the address of the deal tokens
    **/
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

        //give the market maker (underwriter who change junior tranche deal for a perpetual token a yield)
        marketMakersRedeems[msg.sender] =  marketMakersRedeems[msg.sender] + _amount;
        marketMakersTimings[msg.sender] = block.timestamp + marketmakersRedeemTime;

    }

    /**
     * @dev receive repayments of the deal tokens in this pool
     * @param _amount the amount of the repayment done by the specific deal contract
    **/
    function receiveRepayments(uint256 _amount) public {
        //check the caller is a deal
        require(dealsFactory.getDealState(msg.sender), "This deal contract does not exist");
        //reinvest the funds in another deal
        if(_amount > deals[msg.sender]){
            totalInterests = totalInterests + ((_amount - deals[msg.sender]) * (100-marketmakersFee)/100) ;
            totalMarketMakersFee = totalMarketMakersFee + ((_amount - deals[msg.sender]) * (marketmakersFee)/100);
            deals[msg.sender] = 0;
        }
        else{
            deals[msg.sender] = deals[msg.sender] - _amount;
        }
        reinvest(_amount);
    }

    /**
     * @dev reinvest the repayments of the deal tokens, in perpetual bonds the principal repayed is immediately reinvested
     * @param _amount the amount of the reinvestment
    **/
    function reinvest (uint256 _amount) internal {
        amountToInvest = amountToInvest + _amount;
        uint i = 0;
        while (amountToInvest>0 && dealsFactory.getDealByIndex(i) != address(this)){ //to modify with address null
                if(dealsFactory.getDealState(dealsFactory.getDealByIndex(i))){
                    bentobox.transfer(DAI, address(this), dealsFactory.getDealByIndex(i), amountToInvest);
                    uint256 juniorInvested = Deal(dealsFactory.getDealByIndex(i)).emitTokensToInvestors(address(this), amountToInvest);
                    amountToInvest = amountToInvest - juniorInvested;
                    //TD modify APR pool
                }
            }
        
    }
    
    /**
     * @dev function called by the token holders for redeem their interest from theirs perpetual bonds
    **/
    function redeemInterests() public {
        require(balanceOf(msg.sender)>0, "you have no perpetual bonds");
        uint256 interests = balanceOf(msg.sender) * aprPool * ((block.timestamp - holdersRedeems[msg.sender])/365);
        bentobox.withdraw(DAI, address(this), msg.sender, interests ,0);
        holdersRedeems[msg.sender] = block.timestamp;
    }

    /**
     * @dev function called by the marketMakers for redeem their yield for creating perpetual bonds
    **/
    function redeemMarketMakersInterests() public {

        //controlla che redeemtime sia maggiore di block timestamp
        require(marketMakersTimings[msg.sender] >= block.timestamp, "You can't withdraw your yield yet");
        uint256 interests = marketMakersRedeems[msg.sender] * marketmakersFee * ((marketmakersRedeemTime)/365);
        bentobox.withdraw(DAI, address(this), msg.sender, interests ,0);
        totalMarketMakersFee = totalMarketMakersFee - interests;
        marketMakersRedeems[msg.sender] = 0;
    }
}