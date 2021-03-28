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

  
  const TokenERC20 = await hre.ethers.getContractFactory("TokenERC20");

  const toeknA = await TokenERC20.deploy(18, "TokenA", "TOA");
  await toeknA.deployed();
  console.log('tokenA address', toeknA.address);

  const toeknB = await TokenERC20.deploy(18, "TokenB", "TOB");
  await toeknB.deployed();
  console.log('toeknB address', toeknB.address)

  console.log('start uniswapV2Factory')
  const UniswapV2Factory = await hre.ethers.getContractFactory("UniswapV2Factory");
  const uniswapV2Factory = await UniswapV2Factory.deploy('0x76Ee3eEb7F5B708791a805cCa590aead4777D378');
  await uniswapV2Factory.deployed();
  console.log('end uniswapV2Factory')
  await sleep()

  console.log('start createPair')
  await uniswapV2Factory.createPair(toeknA.address, toeknB.address);
  console.log('end createPair')
  await sleep()

// 路由合约
  const ChaingeSwap = await hre.ethers.getContractFactory("ChaingeSwap");
  const chaingeSwap = await ChaingeSwap.deploy("0x8Bc0D62BAD129C03fDc67A1d2fff321004eC50D5", "0x6F7b906f868C3fb4770f506dcdD3E7dBc72C37A2");
  await chaingeSwap.deployed();
  console.log("Greeter deployed to:", chaingeSwap.address);

  await sleep()
  console.log("approve start");
  // 给路由合约授权
  await toeknA.approve(chaingeSwap.address, 999999999999)
  console.log("approve end");
  await sleep()
  console.log("approve start");
  await toeknB.approve(chaingeSwap.address, 999999999999)
  console.log("approve end");
  await sleep()

  console.log("开始调用 addLiquidity");
  console.log(await chaingeSwap.addLiquidity(
    toeknA.address,
    toeknB.address,
    111,
    11,
    111,
    11,
    '0x76Ee3eEb7F5B708791a805cCa590aead4777D378',
    9999999999999
  ))
  console.log('addLiquidity 完成');

  await sleep()

  const swapResult = await chaingeSwap.swapExactTokensForTokensSupportingFeeOnTransferTokens(
    8,
    0,
    [toeknA.address, toeknB.address],
    '0x76Ee3eEb7F5B708791a805cCa590aead4777D378',
    99999999999999,
  )

   console.log(swapResult)
    console.log('完成了');
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
      }, 10000)
  })
}