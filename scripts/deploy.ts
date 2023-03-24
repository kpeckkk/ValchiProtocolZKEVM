import { ethers } from "hardhat";
import { extendConfig } from "hardhat/config";

import managerABI from "../abi/contracts/Governance/Manager.sol/Manager.json"
import { DAIcontractZKEVM } from "../test/common";


async function main() {
  
      //let encodedAddresses = ethers.utils.defaultAbiCoder.encode([ "address", "address"], [ "0x2Cdf4844455c7dA5112B8e48341b964FD2e67727", DAIcontractZKEVM]);
      //console.log(encodedAddresses);
      await updateAddresses();
  }

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

async function deployManager () {
  const Manager = await ethers.getContractFactory("Manager");
  const manager = await Manager.deploy();
  await manager.deployed();

  console.log("manager:")
  console.log(manager.address);
}

async function deployIdentityToken () {
  const IdentityToken = await ethers.getContractFactory("IdentityToken");
  const identityToken = await IdentityToken.deploy();
  await identityToken.deployed();
  
  console.log("Identity Token:");
  console.log(identityToken.address);
}

async function deployDealsFactory () {
  const DealsFactory = await ethers.getContractFactory("DealsFactory");
  const dealsFactory = await DealsFactory.deploy(ethers.utils.getAddress("0x2Cdf4844455c7dA5112B8e48341b964FD2e67727"));
  await dealsFactory.deployed();


  console.log("DealsFactory:")
  console.log(dealsFactory.address);
}

async function deployInvestorsRouter () {
  let encodedAddresses = ethers.utils.defaultAbiCoder.encode([ "address", "address"], [ "0x2Cdf4844455c7dA5112B8e48341b964FD2e67727", DAIcontractZKEVM]);

  //deploy contract InvestorsRouter.sol
  const InvestorsRouter = await ethers.getContractFactory("InvestorsRouter");
  const investorsRouter = await InvestorsRouter.deploy(encodedAddresses);
  await investorsRouter.deployed();

  console.log("InvestorsRouter:")
  console.log(investorsRouter.address);
}

async function deployLiquidityPool () {
  let encodedAddresses = ethers.utils.defaultAbiCoder.encode([ "address", "address"], [ "0x2Cdf4844455c7dA5112B8e48341b964FD2e67727", DAIcontractZKEVM]);

  //deploy contract LiquidityPool.sol
  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  const liquidityPool = await LiquidityPool.deploy(encodedAddresses, 90,95,91);
  await liquidityPool.deployed();


  console.log("LiquidityPool:")
  console.log(liquidityPool.address);
}

async function deployConversionPool () {
  let encodedAddresses = ethers.utils.defaultAbiCoder.encode([ "address", "address"], [ "0x2Cdf4844455c7dA5112B8e48341b964FD2e67727", DAIcontractZKEVM]);

  //deploy contract ConversionPool.sol
  const ConversionPool = await ethers.getContractFactory("ConversionPool");
  const conversionPool = await ConversionPool.deploy(encodedAddresses,1,365);
  await conversionPool.deployed();

  console.log("ConversionPool:")
  console.log(conversionPool.address);
}

async function updateAddresses (){
  const manager = new ethers.Contract("0x2Cdf4844455c7dA5112B8e48341b964FD2e67727", managerABI, ethers.provider.getSigner())

  //await manager.setLeverage(1);
  //await manager.setUnderwriterFee(70);
  //await manager.setPerformanceFee(10);
  //await manager.setDefaultReserveRatio(10);

  await manager.setAddress(3,"0xe01D582E3F06BBa926AF1Ea6A423b6e356fd342D");
  
    // 1 => IdentityToken
    // 2 => DealsFactory
    // 3 => InvestorsRouter
    // 4 => LiquidityPool
    // 5 => ConversionPool
  console.log("done");

}