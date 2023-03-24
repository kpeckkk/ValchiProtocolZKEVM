import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";
import { DAIcontractZKEVM, DAIwhaleZKEVM } from "./common";
import { getTokens } from "./Types";


describe("Integration tests", function () {
    it("Should give identity token", async function () {
        let protocolAccount= {} as SignerWithAddress;
        let user= ethers.Wallet.createRandom();

        [protocolAccount] = await ethers.getSigners();

        //deploy contract IdentityToken.sol
        const IdentityToken = await ethers.getContractFactory("IdentityToken");
        const identityToken = await IdentityToken.connect(protocolAccount).deploy();
        await identityToken.deployed();

        //give the identity nft to a user
        await identityToken.connect(protocolAccount).approveIdentity(user.address,"ValchiWhitelisted");

    })
    it("Should create a deal", async function () {
        let protocolAccount= {} as SignerWithAddress;
        let user= ethers.Wallet.createRandom();

        [protocolAccount] = await ethers.getSigners();

        //SET GENERAL CONTRACTS -------------------------------------------------------------------
        //deploy contract Manager.sol
        const Manager = await ethers.getContractFactory("Manager");
        const manager = await Manager.connect(protocolAccount).deploy();
        await manager.deployed();

        //deploy contract IdentityToken.sol
        const IdentityToken = await ethers.getContractFactory("IdentityToken");
        const identityToken = await IdentityToken.connect(protocolAccount).deploy();
        await identityToken.deployed();

        //set variables on Manager.sol
        await manager.connect(protocolAccount).setAddress(1,identityToken.address);
        await manager.connect(protocolAccount).setLeverage(1);
        await manager.connect(protocolAccount).setUnderwriterFee(70);
        await manager.connect(protocolAccount).setPerformanceFee(10);
        await manager.connect(protocolAccount).setDefaultReserveRatio(10);


         //deploy contract DealFactory.sol
         const DealsFactory = await ethers.getContractFactory("DealsFactory");
         const dealsFactory = await DealsFactory.connect(protocolAccount).deploy(manager.address);
         await dealsFactory.deployed();

        //CREATE THE DEAL -------------------------------------------------------------------

        //deploy contract Deal and TokenDeal , after an ok KYB process
        const loanAmount = 100;
        const loanInterest = 4
        let encodedAddresses = ethers.utils.defaultAbiCoder.encode([ "address", "address"], [ manager.address, DAIcontractZKEVM]);
        let encodedLoanData = ethers.utils.defaultAbiCoder.encode([ "address", "uint256", "uint256" ], [ user.address, loanAmount , loanInterest ]);
        const Deal = await ethers.getContractFactory("Deal");
        const deal = await Deal.connect(protocolAccount).deploy(encodedAddresses,encodedLoanData, {
            gasLimit: 4000000,
          });
        await deal.deployed();

        const TokenDeal = await ethers.getContractFactory("TokenDeal");
        const tokenDeal = await TokenDeal.connect(protocolAccount).deploy(deal.address, loanAmount , deal.address, deal.address, {
            gasLimit: 4000000,
          }); //the 3 and 4 address aren't rights
        await tokenDeal.deployed();

        await dealsFactory.addDeal(deal.address);

    })
    it("Should underwrite a junior tranche of a deal", async function () {
        let protocolAccount= {} as SignerWithAddress;
        let user= ethers.Wallet.createRandom();
        let investor= ethers.Wallet.createRandom();


        [protocolAccount] = await ethers.getSigners();

        //SET GENERAL CONTRACTS -------------------------------------------------------------------
        //deploy contract Manager.sol
        const Manager = await ethers.getContractFactory("Manager");
        const manager = await Manager.connect(protocolAccount).deploy();
        await manager.deployed();

        let encodedAddresses = ethers.utils.defaultAbiCoder.encode([ "address", "address"], [ manager.address, DAIcontractZKEVM]);

        //deploy contract IdentityToken.sol
        const IdentityToken = await ethers.getContractFactory("IdentityToken");
        const identityToken = await IdentityToken.connect(protocolAccount).deploy();
        await identityToken.deployed();

        //give the identity nft to a user
        await identityToken.connect(protocolAccount).approveIdentity(user.address,"ValchiWhitelisted");
        await identityToken.connect(protocolAccount).approveIdentity(investor.address,"ValchiWhitelisted");


        //set variables on Manager.sol
        await manager.connect(protocolAccount).setAddress(1,identityToken.address);
        await manager.connect(protocolAccount).setLeverage(1);
        await manager.connect(protocolAccount).setUnderwriterFee(70);
        await manager.connect(protocolAccount).setPerformanceFee(10);
        await manager.connect(protocolAccount).setDefaultReserveRatio(10);


         //deploy contract DealFactory.sol
         const DealsFactory = await ethers.getContractFactory("DealsFactory");
         const dealsFactory = await DealsFactory.connect(protocolAccount).deploy(manager.address);
         await dealsFactory.deployed();

        //deploy contract InvestorsRouter.sol
        const InvestorsRouter = await ethers.getContractFactory("InvestorsRouter");
        const investorsRouter = await InvestorsRouter.connect(protocolAccount).deploy(encodedAddresses);
        await investorsRouter.deployed();

        //deploy contract LiquidityPool.sol
        const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
        const liquidityPool = await LiquidityPool.connect(protocolAccount).deploy(encodedAddresses, 90,95,91);
        await liquidityPool.deployed();

        //deploy contract ConversionPool.sol
        const ConversionPool = await ethers.getContractFactory("ConversionPool");
        const conversionPool = await ConversionPool.connect(protocolAccount).deploy(encodedAddresses,1,365);
        await conversionPool.deployed();
        
        await manager.connect(protocolAccount).setAddress(2,dealsFactory.address);
        await manager.connect(protocolAccount).setAddress(3,investorsRouter.address);
        await manager.connect(protocolAccount).setAddress(4,liquidityPool.address);
        await manager.connect(protocolAccount).setAddress(5,conversionPool.address);

        await investorsRouter.setLiquidityPool();

        //CREATE THE DEAL -------------------------------------------------------------------

        //deploy contract Deal and TokenDeal , after an ok KYB process
        const loanAmount = 100;
        const loanInterest = 4
        let encodedLoanData = ethers.utils.defaultAbiCoder.encode([ "address", "uint256", "uint256" ], [ user.address, loanAmount , loanInterest ]);
        const Deal = await ethers.getContractFactory("Deal");
        const deal = await Deal.connect(protocolAccount).deploy(encodedAddresses,encodedLoanData, {
            gasLimit: 4000000,
          });
        await deal.deployed();

        const TokenDeal = await ethers.getContractFactory("TokenDeal");
        const tokenDeal = await TokenDeal.connect(protocolAccount).deploy(deal.address, loanAmount , deal.address, deal.address, {
            gasLimit: 4000000,
          }); //the 3 and 4 address aren't rights
        await tokenDeal.deployed();


        //init of variables
        const DAI = new ethers.Contract(DAIcontractZKEVM, ERC20.abi, ethers.provider); // ERC20 contract of DAI

        //fund DAI
        await getTokens(protocolAccount.address, DAIcontractZKEVM ,DAIwhaleZKEVM, ethers.utils.parseUnits("50000.0",18));

        //trasfer funds to account
        await DAI.connect(protocolAccount).approve(investorsRouter.address,ethers.utils.parseUnits("50000.0",18));


        investorsRouter.connect(protocolAccount).investInDeals(investor.address,deal.address,ethers.utils.parseUnits("50000.0",18));


    })
    it("Should deposit liquidity in the senior pool", async function () {
        let protocolAccount= {} as SignerWithAddress;
        let user= ethers.Wallet.createRandom();
        let investor= ethers.Wallet.createRandom();


        [protocolAccount] = await ethers.getSigners();

        //SET GENERAL CONTRACTS -------------------------------------------------------------------
        //deploy contract Manager.sol
        const Manager = await ethers.getContractFactory("Manager");
        const manager = await Manager.connect(protocolAccount).deploy();
        await manager.deployed();

        let encodedAddresses = ethers.utils.defaultAbiCoder.encode([ "address", "address"], [ manager.address, DAIcontractZKEVM]);

        //deploy contract IdentityToken.sol
        const IdentityToken = await ethers.getContractFactory("IdentityToken");
        const identityToken = await IdentityToken.connect(protocolAccount).deploy();
        await identityToken.deployed();

        //give the identity nft to a user
        await identityToken.connect(protocolAccount).approveIdentity(user.address,"ValchiWhitelisted");
        await identityToken.connect(protocolAccount).approveIdentity(investor.address,"ValchiWhitelisted");


        //set variables on Manager.sol
        await manager.connect(protocolAccount).setAddress(1,identityToken.address);
        await manager.connect(protocolAccount).setLeverage(1);
        await manager.connect(protocolAccount).setUnderwriterFee(70);
        await manager.connect(protocolAccount).setPerformanceFee(10);
        await manager.connect(protocolAccount).setDefaultReserveRatio(10);


         //deploy contract DealFactory.sol
         const DealsFactory = await ethers.getContractFactory("DealsFactory");
         const dealsFactory = await DealsFactory.connect(protocolAccount).deploy(manager.address);
         await dealsFactory.deployed();

        //deploy contract InvestorsRouter.sol
        const InvestorsRouter = await ethers.getContractFactory("InvestorsRouter");
        const investorsRouter = await InvestorsRouter.connect(protocolAccount).deploy(encodedAddresses);
        await investorsRouter.deployed();

        //deploy contract LiquidityPool.sol
        const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
        const liquidityPool = await LiquidityPool.connect(protocolAccount).deploy(encodedAddresses, 90,95,91);
        await liquidityPool.deployed();

        //deploy contract ConversionPool.sol
        const ConversionPool = await ethers.getContractFactory("ConversionPool");
        const conversionPool = await ConversionPool.connect(protocolAccount).deploy(encodedAddresses,1,365);
        await conversionPool.deployed();
        
        await manager.connect(protocolAccount).setAddress(2,dealsFactory.address);
        await manager.connect(protocolAccount).setAddress(3,investorsRouter.address);
        await manager.connect(protocolAccount).setAddress(4,liquidityPool.address);
        await manager.connect(protocolAccount).setAddress(5,conversionPool.address);

        await investorsRouter.setLiquidityPool();

        //CREATE THE DEAL -------------------------------------------------------------------

        //deploy contract Deal and TokenDeal , after an ok KYB process
        const loanAmount = 100;
        const loanInterest = 4
        let encodedLoanData = ethers.utils.defaultAbiCoder.encode([ "address", "uint256", "uint256" ], [ user.address, loanAmount , loanInterest ]);
        const Deal = await ethers.getContractFactory("Deal");
        const deal = await Deal.connect(protocolAccount).deploy(encodedAddresses,encodedLoanData, {
            gasLimit: 4000000,
          });
        await deal.deployed();

        const TokenDeal = await ethers.getContractFactory("TokenDeal");
        const tokenDeal = await TokenDeal.connect(protocolAccount).deploy(deal.address, loanAmount , deal.address, deal.address, {
            gasLimit: 4000000,
          }); //the 3 and 4 address aren't rights
        await tokenDeal.deployed();
       
        //init of variables
        const DAI = new ethers.Contract(DAIcontractZKEVM, ERC20.abi, ethers.provider); // ERC20 contract of DAI

        //fund DAI
        await getTokens(protocolAccount.address, DAIcontractZKEVM ,DAIwhaleZKEVM, ethers.utils.parseUnits("50000.0",18));

        //trasfer funds to account
        await DAI.connect(protocolAccount).approve(investorsRouter.address,ethers.utils.parseUnits("50000.0",18));


        investorsRouter.connect(protocolAccount).investInLiquidityPool(investor.address,ethers.utils.parseUnits("50000.0",18));
    })
});

   

    
  
