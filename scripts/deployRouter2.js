const hre = require("hardhat");
const utils = require('./utils/utils');

// async function main() {
//     const [forLiquidity, forSwap] = await hre.ethers.getSigners();
//     console.log('\x1B[32m%s\x1B[40m', '-------------- Start --------------')
//     const amountA = utils.addZero(1, 16);
//     const amountB = utils.addZero(35, 16);
//     let { tokenA, tokenB } = await utils.mint(
//         forLiquidity,
//         forSwap,
//         utils,
//         {
//             startTime: parseInt(Date.now() / 1000),
//             endTime: 666666666666,
//             amountA,
//             amountB,
//             // 流动性充的量
//             amountADesired: utils.addZero(1, 15),
//             amountBDesired: utils.addZero(4, 16),
//             // 下面两两比例相同
//             amountAMin: utils.addZero(9, 10),
//             amountBMin: utils.addZero(4, 10),
//             amountOut: utils.addZero(9, 13),
//             amountInMax: utils.addZero(4, 13)
//         }
//     )
//     // x*y=k
//     //  
//     const balanceA = await utils._checkBalance([0, 666666666666], forSwap, tokenA)
//     const balanceB = await utils._checkBalance([0, 666666666666], forSwap, tokenB)
//     const balanceC = await utils._checkBalance([0, 666666666666], forLiquidity, tokenA)
//     const balanceD = await utils._checkBalance([0, 666666666666], forLiquidity, tokenB)

//     const swap_k = (amountA - balanceC) * (amountB - balanceD)

//     console.log('---------- mint后 ----------')
//     console.log('TokenA: ', amountA)
//     console.log('TokenB: ', amountB)
//     console.log('---------- swap后 ----------')
//     console.log('TokenA: ', balanceA)
//     console.log('TokenB: ', balanceB)
//     console.log('---------- addLiquidity后 ----------')
//     console.log('TokenA: ', balanceC)
//     console.log('TokenB: ', balanceD)

//     console.log('k: 充了流动性的A * 充了流动性的B', swap_k)

//     const tempA = swap_k / (balanceD - balanceB) + balanceC
//     console.log('手动计算swap后的tokenA内应该有', tempA)
//     console.log('差值', balanceA - tempA)

//     console.log('-------------- swap --------------')
//     console.log('\x1B[32m%s\x1B[0m', '-------------- End --------------')
//     return { balanceA, balanceB }
// }



async function main() {
    const [forLiquidity, forSwap] = await hre.ethers.getSigners();
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
        amountOut: utils.addZero(1, 12),
        amountInMax: utils.addZero(4, 12),
        // removeLiquidity
        liquidity: utils.addZero(1, 12),
        amountAMin: 0,
        amountBMin: 0
    }

    const { tokenA, tokenB } = await utils.mint(forLiquidity, forSwap, utils, config)
    await sleep()
    const { uniswapV2Factory } = await utils.factory(forLiquidity)
    await sleep()
    const pair = await utils.createPair(uniswapV2Factory, tokenA, tokenB, config)
    await sleep()
    const uniRouter = await utils.router(uniswapV2Factory.address, tokenA.address)
    await sleep()
    await utils.approve(uniRouter.address, tokenA, tokenB)
    const afterMint = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    await sleep()

    const res = await utils.addLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, config)
    const afterAddLiquidity = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    await sleep()

    const deltaA = afterMint[0] - afterAddLiquidity[0]
    const deltaB = afterMint[1] - afterAddLiquidity[1]
    const k = (deltaA) * (deltaB)
    console.log(`TokenA充了: ${deltaA}`)
    console.log(`TokenB充了: ${deltaB}`)
    console.log(`k: ${k}`)


    await utils.removeLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, config)
    const afterRemoveLiquidity = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    const removeDeltaA = afterRemoveLiquidity[0] - afterAddLiquidity[0]
    const removeDeltaB = afterRemoveLiquidity[1] - afterAddLiquidity[1]
    console.log(`TokenA退了: ${removeDeltaA}`)
    console.log(`TokenB退了: ${removeDeltaB}`)
    console.log(`k: ${removeDeltaA * removeDeltaB}`)


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