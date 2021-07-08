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
  const [owner, forSwap] = await hre.ethers.getSigners();
  // await hre.run('compile');

  // We get the contract to deploy

  // 创建一个758代币， 支持1820接口

  // 然后创建 挖矿合约， 注册到1820.

  // 然后调用758的mint看看是否调用了挖矿合约



 // 直接测试 LP token的合约
  const FRC758 = await hre.ethers.getContractFactory("ChaingeDexFRC758");

  const lp = await FRC758.deploy();

  await lp.deployed();

  // await sleep()

  const Minning = await hre.ethers.getContractFactory("Minning");

  const minning = await Minning.deploy(lp.address);

  await minning.deployed();

  console.log("minning deployed to:", minning.address);

  console.log(minning.address)
  await lp.setHooks(minning.address);

  await lp.mint(owner.address, '111111111111111111111111111111111111');

  const bal = await minning.balanceOf(owner.address); // 收益余额
  console.log('收益的余额:', parseInt(bal._hex));

  //  await lp.timeSliceTransferFrom(owner.address, lp.address,  '111111111111111111111111111111111111',  Math.ceil(Date.now() / 1000),  Math.ceil(Date.now() / 1000) + 100000);

  // console.log("Greeter deployed to:", minning);

  // await minning.addBalance(owner.address, 10000000000);

  // const bal = await minning.balanceOf(owner.address);

  // console.log( parseInt(bal._hex));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
