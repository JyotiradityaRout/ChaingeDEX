// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy

  // const UniswapV2Router02 = await hre.ethers.getContractFactory("UniswapV2Router02");
  // const UniswapV2Router02 = await Greeter.deploy("0xfabb0ac9d68b0b445fb7357272ff202c5651694a");
  
  // await uniswapV2Router02.deployed();
  // console.log("Greeter deployed to:", uniswapV2Router02.address);


  const {toeknA, toeknB} = await depErc20()

  await sleep()
  const {uniswapV2Factory} = await factory()

  const pair =  await createPair(uniswapV2Factory, toeknA, toeknB)
  await sleep()
  const uniRouter = await router(uniswapV2Factory.address, toeknA.address)

  await sleep()
  await approve(uniRouter.address, toeknA, toeknB)

  await sleep()
  await addLiquidity(uniRouter, toeknA.address, toeknB.address)

  await sleep()
  await swap(uniRouter, toeknA.address, toeknB.address)

  await checkBalance(toeknA, toeknB)
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
      }, 5000)
  })
}

async function depErc20() {
  const TokenERC20 = await hre.ethers.getContractFactory("TokenERC20");

  const toeknA = await TokenERC20.deploy(18, "TokenA", "TOA");
  await toeknA.deployed();
  await sleep()
  console.log('tokenA address', toeknA.address);
  await toeknA.mint(18000000000)
  await sleep()
  const toeknB = await TokenERC20.deploy(18, "TokenB", "TOB");
  await toeknB.deployed();
  await sleep()
  await toeknB.mint(18000000000)
  console.log('toeknB address', toeknB.address)

  return {
    toeknA,
    toeknB
  }
}

async function factory() {
  console.log('start uniswapV2Factory')
  const UniswapV2Factory = await hre.ethers.getContractFactory("UniswapV2Factory");
  const uniswapV2Factory = await UniswapV2Factory.deploy('0x76Ee3eEb7F5B708791a805cCa590aead4777D378');
  await uniswapV2Factory.deployed();
  console.log('end uniswapV2Factory')
  await sleep()
  return {
    uniswapV2Factory: uniswapV2Factory
  }
}

async function createPair(factory, addressA, addressB) {
  console.log('start createPair')
  // console.log(addressA)
  // console.log(addressB)
  const pair = await factory.createPair(addressA.address, addressB.address);
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
  await tokenA.approve(routerAddress, 999999999999)
  console.log("approve end");
  await sleep()
  console.log("approve start");
  await tokenB.approve(routerAddress, 999999999999)
  console.log("approve end");
}

async function addLiquidity(uniRouter, addressA, addressB) {
  console.log("开始调用 addLiquidity");
  console.log(await uniRouter.addLiquidity(
    addressA,
    addressB,
    11100000000,
    10001,
    11100000000,
    10001,
    '0x76Ee3eEb7F5B708791a805cCa590aead4777D378',
    9999999999999
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