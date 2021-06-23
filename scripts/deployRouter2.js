const hre = require("hardhat");
const utils = require('./utils/utils');

async function main() {
    const [forLiquidity, forSwap] = await hre.ethers.getSigners();
    const amountA = '100000000000000000000';
    const amountB = '15000000';
    const timer = parseInt(Date.now() / 1000)
    
    const config = {
        startTime: '1619395996',
        endTime: '18446744073709551615',
        amountA,
        amountB,
        // 流动性充的量
        amountADesired: amountA,
        amountBDesired: amountB,
        // addLiquidity swap两两比例相同
        // addLiquidity
        amountAMin: utils.addZero(1, 12),
        amountBMin: utils.addZero(4, 12),
        // swap
        amountOut: utils.addZero(1, 10),
        amountInMax: utils.addZero(4, 10),
        // removeLiquidity
        // liquidity: utils.addZero(1, 12),
        amountAMin: 0,
        amountBMin: 0
    }

    const { tokenA, tokenB, tokenC} = await utils.mint(forLiquidity, forLiquidity, utils, config)
    await sleep()

    const { uniswapV2Factory } = await utils.factory(forLiquidity)
    await sleep()

    const pair = await utils.createPair(uniswapV2Factory, tokenA, tokenB, config)
    console.log('pair合约地址:', pair);
    await sleep()
    
    // await utils.createPair(uniswapV2Factory, tokenB, tokenC, config)
    // await sleep()

    const uniRouter = await utils.router(uniswapV2Factory.address, tokenA.address)
    await sleep()

    await utils.approve(uniRouter.address, tokenA, tokenB)
    const afterMint = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    await sleep()

    const res = await utils.addLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, config) // A and B

    // await utils.addLiquidity(forLiquidity, uniRouter, tokenB.address, tokenC.address, config) // B and C

    const afterAddLiquidity = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    await sleep()

    const deltaA = afterMint[0] - afterAddLiquidity[0]
    const deltaB = afterMint[1] - afterAddLiquidity[1]
    const k = (deltaA) * (deltaB)
    // 1000是最小流通量
    const liq = Math.sqrt(deltaA * deltaB) - 1000
    console.log(`TokenA充了: ${deltaA}`)
    console.log(`TokenB充了: ${deltaB}`)
    console.log(`k: ${k}`)
    console.log(`理论上liquidity的值：${liq}`)


    // 获取 pair合约的LP token的值

    const chaingeDexPair = await hre.ethers.getContractAt('ChaingeDexPair', pair);
    // console.log('forLiquidity', forLiquidity.address);

    // const lpBal = await chaingeDexPair.balanceOf(forLiquidity.address)
    // console.log('我拥有的 LP 数量:',parseInt(lpBal._hex));

    await chaingeDexPair.approve(uniRouter.address, '19999999990000000000000000000000000');

    // await sleep()

    // await utils.removeLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, utils.addZero(1, 10), config)
    // const afterRemoveLiquidity = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    // const removeDeltaA = afterRemoveLiquidity[0] - afterAddLiquidity[0]
    // const removeDeltaB = afterRemoveLiquidity[1] - afterAddLiquidity[1]
    // const _k = removeDeltaA * removeDeltaB * Math.pow(deltaA / removeDeltaA, 2)
    // console.log(`TokenA退了: ${removeDeltaA}`)
    // console.log(`TokenB退了: ${removeDeltaB}`)
    // console.log(`removeLiquidity后，k的理论值: ${_k}`)
    // console.log(`result：${k === _k}`)

    await sleep()
    
    await utils.swap2(forLiquidity, uniRouter, tokenA.address, tokenB.address, config)
    const afterSwap = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    console.log(`swap后，tokenA的理论值：${k / (deltaB)}`)
    console.log(`result：${k / (deltaB) === deltaA}`)

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
    return new Promise(function (res, rej) {
        setTimeout(() => {
            res()
        }, 15000)
    })
}
module.exports.main = main