// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const signers = {}

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');

 const [owner] = await hre.ethers.getSigners();
 signers.address = owner.address
  console.log('owner:', owner.address)
  // We get the contract to deploy

  // const UniswapV2Router02 = await hre.ethers.getContractFactory("UniswapV2Router02");
  // const UniswapV2Router02 = await Greeter.deploy("0xfabb0ac9d68b0b445fb7357272ff202c5651694a");
  
  // await uniswapV2Router02.deployed();
  // console.log("Greeter deployed to:", uniswapV2Router02.address);

  // const {toeknA, toeknB} = await depErc20()


  const {tokenA, tokenB} = await frc758()

  await sleep()
  const {uniswapV2Factory} = await factory()

  const pair =  await createPair(uniswapV2Factory, tokenA, tokenB)
  await sleep()
  const uniRouter = await router(uniswapV2Factory.address, tokenA.address)

  await sleep()
  await approve(uniRouter.address, tokenA, tokenB)

  await sleep()
  await addLiquidity(uniRouter, tokenA.address, tokenB.address)

  // await sleep()
  // await swap(uniRouter, tokenA.address, tokenB.address)

  // await checkBalance(tokenA, tokenB)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });


async function sleep() {
  return new Promise(function(res, rej) {
      setTimeout(() => {
          res()
      }, 0)
  })
}

async function depErc20() {
  const TokenERC20 = await hre.ethers.getContractFactory("TokenERC20");
  const tokenA = await TokenERC20.deploy(18, "TokenA", "TOA");
  await tokenA.deployed();
  await sleep()
  console.log('tokenA address', tokenA.address);
  await tokenA.mint(18000000000)
  await sleep()
  const tokenB = await TokenERC20.deploy(18, "TokenB", "TOB");
  await tokenB.deployed();
  await sleep()
  await tokenB.mint(18000000000)
  console.log('toeknB address', tokenB.address)

  return {
    tokenA,
    tokenB
  }
}

async function frc758() {
  const FRC758 = await hre.ethers.getContractFactory("FRC758");
  const tokenA = await FRC758.deploy("TokenA", "F1", 18);
  await tokenA.deployed();
  await sleep()

  // console.log( await tokenA.name())
  // console.log( tokenA.balanceOf)

  console.log('tokenA address', tokenA.address);
  await tokenA.mint(signers.address , 18000000000)
  const bal = await tokenA.balanceOf(signers.address, 1617412453, 666666666666, false); // startTime 必须大于当前时间
  console.log(bal)

  await sleep()
  const tokenB = await FRC758.deploy("TokenB", "F2", 18);
  await tokenB.deployed();
  await sleep()

  await tokenB.mint(signers.address, 18000000000)
  console.log('toeknB address', tokenB.address)

  return {
    tokenA,
    tokenB
  }
}

async function factory() {
  console.log('start uniswapV2Factory')
  const UniswapV2Factory = await hre.ethers.getContractFactory("UniswapV2Factory");
  const uniswapV2Factory = await UniswapV2Factory.deploy(signers.address );
  await uniswapV2Factory.deployed();
  console.log('end uniswapV2Factory')
  await sleep()
  return {
    uniswapV2Factory: uniswapV2Factory
  }
}

async function createPair(factory, tokenA, tokenB) {
  console.log('start createPair')
  const pair = await factory.createPair(tokenA.address, tokenB.address, [ 1617212453,666666666666, 1627212453,666666666666]); // 创建个1617212453 到永远的和 1627212453 到永远的。
  console.log('end createPair')
  return pair
}

async function router (factory, weth) {
  // 路由合约
  const Router = await hre.ethers.getContractFactory("ChaingeSwap");

  const uniRouter = await Router.deploy(factory, weth);

  await uniRouter.deployed();
  console.log("Greeter deployed to:", uniRouter.address);
  return uniRouter
}

async function approve(routerAddress, tokenA, tokenB) {
  console.log("approve start");
  // 给路由合约授权
  await tokenA.setApprovalForAll(routerAddress, true)
  console.log("approve end");
  await sleep()
  console.log("approve start");
  await tokenB.setApprovalForAll(routerAddress, true)
  console.log("approve end");
}

async function addLiquidity(uniRouter, addressA, addressB) {
  console.log("开始调用 addLiquidity");
  console.log(await uniRouter.addLiquidity(
    addressA,
    addressB,
    11100000,
    1000100,
    11100000,
    1000100,
    '0x76Ee3eEb7F5B708791a805cCa590aead4777D378',
    9999999999999,
    [1617212453,666666666666,1627212453,666666666666]
  ))
  console.log('addLiquidity 完成');
}

async function swap(uniRouter, addressA, addressB) {
  const swapResult = await uniRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
    8000000,
    7,
    [addressA, addressB],
    '0x76Ee3eEb7F5B708791a805cCa590aead4777D378',
    99999999999999,
  )
    console.log(swapResult)
    console.log('完成了swap');
}

async function checkBalance(tokenA, tokenB) {
  const balanceA = await tokenA.balanceOf('0x76Ee3eEb7F5B708791a805cCa590aead4777D378')
  const balanceB = await tokenB.balanceOf('0x76Ee3eEb7F5B708791a805cCa590aead4777D378')

  console.log(parseInt(balanceA._hex), parseInt(balanceB._hex));
}