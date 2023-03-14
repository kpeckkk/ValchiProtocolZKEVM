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
import { ILiquidityPool } from "../interfaces/ILiquidityPool.sol";
import { IConversionPool } from "../interfaces/IConversionPool.sol";


//the ERC20 contract for deal's tokens
import { TokenDeal } from "../core/TokenDeal.sol";

//bentobox contracts
import { IBentobox } from "../interfaces/Bentobox/IBentobox.sol";
import { IMasterContractManager } from "../interfaces/Bentobox/IMasterContractManager.sol";


contract Deal is Ownable{

    TokenDeal private tokens;

    ERC20 private DAI;
    IBentobox private bentobox;
    IMasterContractManager private masterContractManagerBentobox;

    IIdentityToken private identityToken;
    IManager private manager;
    IInvestorsRouter private investorsRouter;
    ILiquidityPool private liquidityPool;
    IConversionPool private conversionPool;

    uint256 private leverage;
    uint256 private underwriterFee;
    uint256 private performanceFee;
    uint256 private defaultReserveRatio;

    using Counters for Counters.Counter;
    Counters.Counter private _investorsCounter;


    struct data {
        address originator;
        uint256 amount;
        uint256 interest;
        uint256 juniorTokens; //total tokens to junior tranche
        uint256 collectedJunior; //total tokens collected from junior tranche
        uint256 toRepayJunior; //total tokens to repay to junior tranche
        uint256 repayedJunior; //total tokens repayed to junior tranche
        uint256 seniorTokens; //total tokens to senior tranche
        uint256 collectedSenior; //total tokens collected from senior tranche
        uint256 toRepaySenior;  //total tokens to repay to senior tranche
        uint256 repayedSenior; //total tokens repayed to senior tranche
    }
    data private loanData; 

    mapping (uint256 => address) public investorsAddresses; //number with an incremental counter for a better access from the frontend
    mapping (address => uint256) public investorsAmounts; //investors amount invested
    uint256 public liquidityPoolAmount;


    constructor(bytes memory _encodedAddresses, bytes memory _encodedLoanData) {
        
        //set the contracts interfaces     
        address _managerAddress;
        address _DAIAddress;
        address _bentoboxAddress; 
        address _masterContractManagerBentoboxAddress;  
        (_managerAddress, _DAIAddress, _bentoboxAddress, _masterContractManagerBentoboxAddress) = abi.decode(_encodedAddresses,(address,address,address,address));
        manager = IManager(_managerAddress);
        DAI = ERC20(_DAIAddress);
        bentobox = IBentobox(_bentoboxAddress);
        masterContractManagerBentobox = IMasterContractManager(_masterContractManagerBentoboxAddress);
        identityToken = IIdentityToken(manager.getAddress(1));
        investorsRouter = IInvestorsRouter(manager.getAddress(3));
        liquidityPool = ILiquidityPool(manager.getAddress(4));
        conversionPool = IConversionPool(manager.getAddress(5));

        //set the global variables
        leverage = manager.getLeverage();
        underwriterFee = manager.getUnderwriterFee();
        performanceFee = manager.getPerformanceFee();
        defaultReserveRatio = manager.getDefaultReserveRatio();

        //set the loan variables
        (loanData.originator, loanData.amount, loanData.interest) = abi.decode(_encodedLoanData,(address,uint256,uint256));
        loanData.juniorTokens = (loanData.amount / leverage);
        loanData.collectedJunior=0;
        loanData.toRepayJunior = (loanData.amount / leverage) + (loanData.amount * (loanData.interest*(1 - performanceFee + (leverage*underwriterFee))));
        loanData.repayedJunior=0;
        loanData.seniorTokens = (loanData.amount - (loanData.amount / leverage));
        loanData.collectedSenior=0;
        loanData.toRepaySenior = (loanData.amount - (loanData.amount / leverage)) + (loanData.amount*(loanData.interest*(1-performanceFee-underwriterFee)));
        loanData.repayedSenior=0;
        liquidityPoolAmount = 0;
        

        //create the ERC20 contract for the tokens
        tokens = new TokenDeal(loanData.amount, address(identityToken), address(conversionPool));

        //initialize bentobox
        masterContractManagerBentobox.registerProtocol();
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
    ) internal {
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
     * @dev called by the investorsRouter when someone invests new funds
     * @param _investor the address of the investor
     * @param _amount the amount of funds
    **/
    function emitTokensToInvestors (address _investor, uint256 _amount) public returns (uint256) {
        //richiamato dopo il transfer fatto dall'investor router
        if(msg.sender == address(liquidityPool)){
            if(loanData.seniorTokens >= loanData.collectedSenior){
                uint256 _amountInSenior;
                if(loanData.seniorTokens >= loanData.collectedSenior + _amount){
                    _amountInSenior = _amount;
                } else {
                    _amountInSenior = loanData.seniorTokens - loanData.collectedSenior;
                }
                tokens.transfer(msg.sender,_amount);
                loanData.collectedSenior = loanData.collectedSenior + _amountInSenior;
                liquidityPoolAmount = liquidityPoolAmount + _amountInSenior;
                return _amountInSenior;
            }
            return 0;
        } else{
            require(msg.sender == address(investorsRouter) || msg.sender == address(conversionPool), "You have no the privileges to call this function");
            require(loanData.juniorTokens >= loanData.collectedJunior + _amount, "Already funded");
            tokens.transfer(_investor,_amount);
            loanData.collectedJunior = loanData.collectedJunior + _amount;
            investorsAddresses[_investorsCounter.current()] = _investor;
            investorsAmounts[_investor] = _amount;
            _investorsCounter.increment();
            return _amount;
        }
    }


    /**
     * @dev called by the originator when wants to repay the loan (or a part of it) - repay first the senior tokens
     * @param _amount the amount of funds
    **/
    function repayFunds (uint256 _amount) public {
        bentobox.deposit(DAI,msg.sender,address(this),_amount,0);
        //repay before senior tranches and then junior tranches
        if(loanData.repayedJunior + _amount <= loanData.toRepayJunior){
            loanData.repayedJunior = loanData.repayedJunior + _amount;
            //emit event to repay 
        } else if (loanData.repayedJunior < loanData.toRepayJunior && loanData.repayedJunior + _amount > loanData.toRepayJunior){
            loanData.repayedJunior = loanData.toRepayJunior;
            //emit event to repay
        } else {
            loanData.repayedSenior = loanData.repayedSenior + _amount;
            distributeRepaymentsSenior(_amount);
        }
    }

    /**
     * @dev called by the governance for distribute the funds to underwriters
     * @param _id identifier of the investor in the loan
    **/
    function distributeRepaymentsJunior(uint256 _id) public onlyOwner {
        require(investorsAmounts[investorsAddresses[_id]]>0, "Already repaid");
        if(investorsAddresses[_id]==address(conversionPool)){
            bentobox.transfer(DAI, address(this), address(liquidityPool), investorsAmounts[investorsAddresses[_id]]);
            conversionPool.receiveRepayments(investorsAmounts[investorsAddresses[_id]]);
        } else {
            bentobox.withdraw(DAI, address(this), investorsAddresses[_id], investorsAmounts[investorsAddresses[_id]] ,0);
        }
        investorsAmounts[investorsAddresses[_id]]=0;
        tokens.burnTokens(investorsAddresses[_id],investorsAmounts[investorsAddresses[_id]]);
        

    }

    /**
     * @dev distribute the funds to liquidity providers
     * @param _amount identifier of the investor in the loan
    **/
    function distributeRepaymentsSenior(uint256 _amount) internal {
       bentobox.transfer(DAI, address(this), address(liquidityPool), _amount);
       liquidityPool.receiveRepayments();
       tokens.burnTokens(address(liquidityPool),_amount);
    }


    /**
     * @dev called by the originator when take the funds collected by the smart contract
     * @param _amount the amount of funds
    **/
    function withdrawFunds (uint256 _amount) public{
        require(msg.sender == loanData.originator, "The request is not submitted by the originator of the contract");
        bentobox.withdraw(DAI, address(this), loanData.originator, _amount,0);
    }

    /**
     * @dev get the address of its tokens
    **/
    function getERC20address () public view returns (address) {
        return address(tokens);
    }

    /**
     * @dev register the new creditor of the deal
     * @param _seller the address of the seller
     * @param _buyer the address of the buyer
    **/
    function transactionConversion (address _seller, address _buyer) public {
        investorsAddresses[_investorsCounter.current()] = _buyer;
        investorsAmounts[_buyer] = investorsAmounts[_seller];
        investorsAmounts[_seller] = 0;
    }


}