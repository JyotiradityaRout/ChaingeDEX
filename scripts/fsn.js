const hre = require("hardhat");
const utils = require('./utils/utils');

async function main() {
    const [owner, forSwap] = await hre.ethers.getSigners();
    const amountA = utils.addZero(1, 18);
    const amountB = utils.addZero(45, 17);
    const timer = parseInt(Date.now() / 1000)

    const config = {
        startTime: 1619395996,
        endTime: 666666666666,
        amountA,
        amountB,
        // 流动性充的量
        amountADesired: utils.addZero(1, 12),
        amountBDesired: utils.addZero(4, 12),
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

    // const { tokenA, tokenB } = await utils.mint(forLiquidity, forSwap, utils, config)
    // await sleep()
    // const { uniswapV2Factory } = await utils.factory(forLiquidity)

    
    // await sleep()
    // const pair = await utils.createPair(uniswapV2Factory, tokenA, tokenB, config)
    // await sleep()
    // const uniRouter = await utils.router(uniswapV2Factory.address, tokenA.address)
    // await sleep()

    const chaingeSwapRouter = await hre.ethers.getContractAt('ChaingeSwap', "0x88c9753368466fa73E28645CE8DCB4969de41753", owner);

    console.log('chaingeSwapRouter', chaingeSwapRouter.address);

    await chaingeSwapRouter.swapTokensForExactTokens('50000000000000000000', '10000000000000000000', 
    ['0xBDFBA95d0a6be5dEcC666175808775af584Bf6f7', '0xEf873D079BBa2589088A7348A7a41dB5d22B4305'],
     '0xdf1FAcbC27E16F2189E35eb652564502e75Ebf77', '1725137200', ["0","18446744073709551615","0","18446744073709551615"]
     );
    // await utils.approve(uniRouter.address, tokenA, tokenB)
    // const afterMint = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    // await sleep()

    // const res = await utils.addLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, config)
    // const afterAddLiquidity = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    // await sleep()

    // const deltaA = afterMint[0] - afterAddLiquidity[0]
    // const deltaB = afterMint[1] - afterAddLiquidity[1]
    // const k = (deltaA) * (deltaB)
    // // 1000是最小流通量
    // const liq = Math.sqrt(deltaA * deltaB) - 1000
    // console.log(`TokenA充了: ${deltaA}`)
    // console.log(`TokenB充了: ${deltaB}`)
    // console.log(`k: ${k}`)
    // console.log(`理论上liquidity的值：${liq}`)

    // await utils.removeLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, utils.addZero(1, 12), config)
    // const afterRemoveLiquidity = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    // const removeDeltaA = afterRemoveLiquidity[0] - afterAddLiquidity[0]
    // const removeDeltaB = afterRemoveLiquidity[1] - afterAddLiquidity[1]
    // const _k = removeDeltaA * removeDeltaB * Math.pow(deltaA / removeDeltaA, 2)
    // console.log(`TokenA退了: ${removeDeltaA}`)
    // console.log(`TokenB退了: ${removeDeltaB}`)
    // console.log(`removeLiquidity后，k的理论值: ${_k}`)
    // console.log(`result：${k === _k}`)

    // await sleep()
    // await utils.swap(forSwap, uniRouter, tokenA.address, tokenB.address, config)
    // const afterSwap = await utils.checkBalance(forSwap, tokenA, tokenB, config)
    // console.log(`swap后，tokenA的理论值：${k / (deltaB)}`)
    // console.log(`result：${k / (deltaB) === deltaA}`)

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
        }, 0)
    })
}
module.exports.main = main