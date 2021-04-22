// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const signers = {}


function getNow() {
  return parseInt(Date.now() / 1000)
}


async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');

 const [owner, other] = await hre.ethers.getSigners();
 signers.address = owner.address
//  console.log('owner:', owner.address)
  // We get the contract to deploy

  // const UniswapV2Router02 = await hre.ethers.getContractFactory("UniswapV2Router02");
  // const UniswapV2Router02 = await Greeter.deploy("0xfabb0ac9d68b0b445fb7357272ff202c5651694a");
  
  // await uniswapV2Router02.deployed();
  // console.log("Greeter deployed to:", uniswapV2Router02.address);

  // const {toeknA, toeknB} = await depErc20()

  const {tokenA, tokenB} = await frc758()

  await sleep()
  const {uniswapV2Factory} = await factory(owner.address, other.address)

  const pair =  await createPair(uniswapV2Factory, tokenA, tokenB)
  await sleep()
  const uniRouter = await router(uniswapV2Factory.address, tokenA.address)

  await sleep()
  await approve(uniRouter.address, tokenA, tokenB)

  await sleep()
  const res = await addLiquidity(uniRouter, tokenA.address, tokenB.address)

  const now = getNow() + 10;

  const bal = await tokenA.timeBalanceOf(signers.address, 1619395996, 666666666666); // startTime 必须大于当前时间
  console.log(' addLiquidity 之后 tokenA balance', parseInt(bal._hex));
  
  const bal2 = await tokenB.timeBalanceOf(signers.address, 1619395996, 666666666666); // startTime 必须大于当前时间
  console.log(' addLiquidity 之后  tokenB balance', parseInt(bal2._hex));

  await feeToBalance( pair, other.address, owner, )
  await sleep()
  await swap(uniRouter, tokenA.address, tokenB.address)

  await checkBalance(tokenA, tokenB)

  await feeToBalance( pair, other.address, owner, )

  await sleep()
  await removeLiquidity(uniRouter, tokenA.address, tokenB.address, 1111111, 1000002507520, 3999990000128)
  await checkBalance(tokenA, tokenB)

  const lpTokenBalance = await feeToBalance( pair, other.address, owner, )
  console.log(lpTokenBalance);
  await feeToRemoveLiquidity(uniRouter, tokenA.address, tokenB.address, lpTokenBalance, 0, 0, other.address);

  const bal3 = await tokenA.timeBalanceOf(other.address, 1619395996, 666666666666); 
  const bal4 = await tokenB.timeBalanceOf(other.address, 1619395996, 666666666666); 
  console.log('feeTo 取出来的A', bal3 )
  console.log('feeTo 取出来的B', bal4 )
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
  const FRC758 = await hre.ethers.getContractFactory("ChaingeTestToken");
  const tokenA = await FRC758.deploy("TokenA", "F1", 18);
  await tokenA.deployed();
  await sleep()

  console.log( await tokenA.name())
  // console.log( tokenA.balanceOf)

  console.log('tokenA address', tokenA.address);

  await tokenA.mint(signers.address , "1000000000000000000")

  const bal = await tokenA.balanceOf(signers.address); // startTime 必须大于当前时间

  console.log('tokenA balance:', parseInt(bal._hex))
  // console.log(msg.sender, balance0, tokenA);
  await sleep()
  const tokenB = await FRC758.deploy("TokenB", "F2", 18);
  await tokenB.deployed();
  await sleep()

  await tokenB.mint(signers.address, "4500000000000000000")
  console.log('toeknB address', tokenB.address)
  const bal2 = await tokenB.balanceOf(signers.address); // startTime 必须大于当前时间
  console.log('tokenB balance:', parseInt(bal2._hex))

  return {
    tokenA,
    tokenB
  }
}

async function factory(addr, otherAddress) {
  console.log('start ChaingeDexFactory')
  const UniswapV2Factory = await hre.ethers.getContractFactory("ChaingeDexFactory");
  const uniswapV2Factory = await UniswapV2Factory.deploy(addr);
  await uniswapV2Factory.deployed();
  console.log('end uniswapV2Factory')
  await sleep()
  
  await uniswapV2Factory.setFeeTo(otherAddress);

  return {
    uniswapV2Factory: uniswapV2Factory
  }
}

async function createPair(factory, tokenA, tokenB) {
  console.log('start createPair')
  const pair = await factory.createPair(tokenA.address, tokenB.address, [ 1619395996,666666666666, 1619395996,666666666666]); // 创建个1617212453 到永远的和 1627212453 到永远的。
  console.log('end createPair')
  return factory.getPair(tokenA.address, tokenB.address, [ 1619395996,666666666666, 1619395996,666666666666]);
  // return pair
}

async function router (factory, weth) {
  // 路由合约
  const Router = await hre.ethers.getContractFactory("ChaingeSwap");

  const uniRouter = await Router.deploy(factory);

  await uniRouter.deployed();
  console.log("路由合约地址:", uniRouter.address);
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
  const now = getNow() + 400;
  const res = await uniRouter.addLiquidity(
    addressA,
    addressB,
    "1000000000000",
    "4000000000000",
    "1000000000000",
    "4000000000000",
    signers.address,
    9999999999999,
    [1619395996, 666666666666,1619395996,666666666666]
  )
  console.log('addLiquidity 完成');
  return res;
}

/*
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
*/ 
async function removeLiquidity(uniRoute, addressA, addressB, liquidity, amountAMin, amountBMin, to) {
  console.log('removeLiquidity start')
  const now = getNow() + 500;
  await uniRoute.removeLiquidity(
    addressA,
    addressB,
    "1999999999000",
    "999999999000",
    "399999999000",
    signers.address,
    9999999999999,
    [1619395996, 666666666666, 1619395996, 666666666666]
  )
  console.log('removeLiquidity success')
}

async function swap(uniRouter, addressA, addressB) {
  console.log('开始swap');
  const swapResult = await uniRouter.swapTokensForExactTokens(
    "1000000000000",
    "3000000000000",
    [addressA, addressB],
    signers.address,
    999999999999,
    [1619395996, 666666666666, 1619395996, 666666666666]
  )
    console.log('完成了swap');
}

async function checkBalance(tokenA, tokenB) {
  const now = getNow() + 500;
  const balanceA = await tokenA.timeBalanceOf(signers.address, 1619395996, 666666666666)
  const balanceB = await tokenB.timeBalanceOf(signers.address, 1619395996, 666666666666)
  console.log('然后A 和 B ',parseInt(balanceA._hex), parseInt(balanceB._hex));
}

async function feeToBalance(pair ,feeToAddress, signersAddress) {
  console.log('feeToAddress', feeToAddress)
   const pairObj = await hre.ethers.getContractAt('ChaingeDexPair', pair, signersAddress)
   const otherBalance = await pairObj.timeBalanceOf(feeToAddress, 1619395996, 666666666666)
   console.log('feeToBalance ',parseInt(otherBalance._hex));
   const signersBalance = await pairObj.timeBalanceOf(signersAddress.address, 1619395996, 666666666666)
   console.log('signersAddress有多少流动性代币 ',parseInt(signersBalance._hex));

  return parseInt(otherBalance._hex)
}

async function feeToRemoveLiquidity(uniRoute, addressA, addressB, liquidity, amountAMin, amountBMin, to) {
  console.log('feeTo 开始取钱', liquidity, amountAMin, amountBMin, to)
  const now = getNow() + 500;
  await uniRoute.removeLiquidity(
    addressA,
    addressB,
    liquidity,
    amountAMin,
    amountBMin,
    to,
    9999999999999,
    [1619395996, 666666666666, 1619395996, 666666666666]
  )
  console.log('removeLiquidity success')
}