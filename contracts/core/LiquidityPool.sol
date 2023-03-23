// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//openzeppelin
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
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


contract LiquidityPool is ERC721, Ownable{

    IBentobox private bentobox;
    IMasterContractManager private masterContractManagerBentobox;

    IIdentityToken private identityToken;
    IManager private manager;
    IInvestorsRouter private investorsRouter;
    IDealsFactory private dealsFactory;
    ERC20 private DAI;


    using Counters for Counters.Counter;
    Counters.Counter private _investorsCounter;
    struct iBToken{
        uint256 principal;
        uint256 entryTime;
    }
    mapping (uint256 => iBToken) public tokens;
    uint256 public totalVolume;
    uint256 public totalInvested;
    uint256 public urate;
    uint256 public targetRateInvestOnDeposits;
    uint256 public targetRateInvestOnRepayments;
    uint256 public targetRateWithdraw;

    uint256 public dealsInterest;
    uint256 public contractInterest;

    constructor(bytes memory _encodedAddresses, uint256 _targetRateInvestOnDeposits, uint256 _targetRateInvestOnRepayments, uint256 _targetRateWithdraw) ERC721("SeniorToken", "STP") {
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
        dealsFactory = IDealsFactory(manager.getAddress(2));
        investorsRouter = IInvestorsRouter(manager.getAddress(3));

        //initialize bentobox
        masterContractManagerBentobox.registerProtocol();

        //set the contract variables
        totalVolume = 0;
        totalInvested = 0;
        targetRateInvestOnDeposits = _targetRateInvestOnDeposits;
        targetRateInvestOnRepayments = _targetRateInvestOnRepayments;
        targetRateWithdraw = _targetRateWithdraw;
        dealsInterest = 0;
        contractInterest = 0;
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
     * @dev emit erc721 interest bearing tokens to the liquidity provider
     * @param _to the address of the liquidity provider
     * @param _amount the amount deposited
    **/
    function emitTokenToInvestors(address _to, uint256 _amount) public {
        // check that the caller is the investor router
        require(msg.sender == address(investorsRouter), "You cannot call this function");
       
        // mint new interest bearing token
         uint256 tokenId = _investorsCounter.current();
        _investorsCounter.increment();
        _safeMint(_to, tokenId);
       
        //mapping tokens with amount invested
        tokens[tokenId].principal = _amount;
        tokens[tokenId].entryTime = block.timestamp;
        totalVolume = totalVolume + _amount;  
        urate = (totalInvested / totalVolume) * 100;
        invest(targetRateInvestOnDeposits);
    }

    /**
     * @dev invest funds received with deposit and repayments of senior tokens in other senior tokens of other deals
     * @param _targetToCheck the utilization rate target to check for reinvest
    **/
    function invest(uint256 _targetToCheck) internal {
        //invest in senior tranche
        //if the target liquidity available is reached
        if(urate < _targetToCheck){
            uint256 i = 0;
            uint256 _amountToInvest = (totalVolume/100)*targetRateInvestOnDeposits - totalInvested;
            while (_amountToInvest>0 && dealsFactory.getDealByIndex(i) != address(0)){ 
                if(dealsFactory.getDealState(dealsFactory.getDealByIndex(i))){
                    bentobox.transfer(DAI, address(this), dealsFactory.getDealByIndex(i), _amountToInvest);
                    uint256 seniorInvested = Deal(dealsFactory.getDealByIndex(i)).emitTokensToInvestors(address(this), _amountToInvest);
                    _amountToInvest = _amountToInvest - seniorInvested;
                    totalInvested = totalInvested + seniorInvested;
                    if(seniorInvested>0)
                    {
                        //TD change dealsInterest
                    }
                }
            }
        }
        urate = (totalInvested / totalVolume) * 100;
        //TD change contractInterest


    }

    /**
     * @dev liquidity provider withdrawal function
     * @param _idToken the interest bearing token to redeem
    **/
    function withdraw(uint256 _idToken) public {
        //withdrawFunds
        //if the target liquidity available is maintaned with the withdraw
        require(tokens[_idToken].principal > 0, "You have no funds invested");
        
        //TO DO 
        // -- compute amount earned based on the interest of the deals in the liqudity pool: 7 is an example of interest of the pool
        uint256 earned = tokens[_idToken].principal * 7 * (block.timestamp - tokens[_idToken].entryTime)/365;
        //
        require(((totalInvested / (totalVolume - tokens[_idToken].principal - earned)) * 100) < targetRateWithdraw, "No Funds on the contract for the withdraw");

        //if the contract have the funds, withdraw them
        bentobox.withdraw(DAI, address(this), ownerOf(_idToken), tokens[_idToken].principal + earned ,0);
        
        //TD change contractInterest


    }

    /**
     * @dev function called by the deal when making a repayment of junior tokens
    **/
    function receiveRepayments() public {
        //check the caller is a deal
        require(dealsFactory.getDealState(msg.sender), "This deal contract does not exist");
        invest(targetRateInvestOnRepayments);

    }

}