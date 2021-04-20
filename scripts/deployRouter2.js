const hre = require("hardhat");
const utils = require('./utils/utils');

async function main() {
    const [forLiquidity, forSwap] = await hre.ethers.getSigners();
    console.log('\x1B[32m%s\x1B[40m', '-------------- Start --------------')
    const amountA = utils.addZero(1, 16);
    const amountB = utils.addZero(35, 16);
    let { tokenA, tokenB } = await utils.mint(
        forLiquidity,
        forSwap,
        utils,
        {
            startTime: parseInt(Date.now() / 1000),
            endTime: 666666666666,
            amountA,
            amountB,
            // 流动性充的量
            amountADesired: utils.addZero(1, 15),
            amountBDesired: utils.addZero(4, 16),
            // 下面两两比例相同
            amountAMin: utils.addZero(9, 10),
            amountBMin: utils.addZero(4, 10),
            amountOut: utils.addZero(9, 13),
            amountInMax: utils.addZero(4, 13)
        }
    )
    // x*y=k
    //  
    const balanceA = await utils._checkBalance([0, 666666666666], forSwap, tokenA)
    const balanceB = await utils._checkBalance([0, 666666666666], forSwap, tokenB)
    const balanceC = await utils._checkBalance([0, 666666666666], forLiquidity, tokenA)
    const balanceD = await utils._checkBalance([0, 666666666666], forLiquidity, tokenB)

    const swap_k = (amountA - balanceC) * (amountB - balanceD)

    console.log('---------- mint后 ----------')
    console.log('TokenA: ', amountA)
    console.log('TokenB: ', amountB)
    console.log('---------- swap后 ----------')
    console.log('TokenA: ', balanceA)
    console.log('TokenB: ', balanceB)
    console.log('---------- addLiquidity后 ----------')
    console.log('TokenA: ', balanceC)
    console.log('TokenB: ', balanceD)

    console.log('k: 充了流动性的A * 充了流动性的B', swap_k)

    const tempA = swap_k / (balanceD - balanceB) + balanceC
    console.log('手动计算swap后的tokenA内应该有', tempA)
    console.log('差值', balanceA - tempA)

    console.log('-------------- swap --------------')
    console.log('\x1B[32m%s\x1B[0m', '-------------- End --------------')
    return { balanceA, balanceB }
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });



module.exports.main = main