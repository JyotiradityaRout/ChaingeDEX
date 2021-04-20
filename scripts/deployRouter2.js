const hre = require("hardhat");
const utils = require('./utils/utils');

async function main() {
    const [forLiquidity, forSwap] = await hre.ethers.getSigners();

    console.log('\x1B[32m%s\x1B[40m', '-------------- Start --------------')
    let { tokenA, tokenB } = await utils.mint(
        forLiquidity,
        forSwap,
        utils,
        {
            startTime: parseInt(Date.now() / 1000),
            endTime: 666666666666,
            amountA: utils.addZero(1, 18),
            amountB: utils.addZero(35, 17),
            amountADesired: utils.addZero(1, 14),
            amountBDesired: utils.addZero(4, 14),
            amountAMin: utils.addZero(9, 10),
            amountBMin: utils.addZero(4, 10),
            amountOut: utils.addZero(10, 12),
            amountInMax: utils.addZero(90, 12)
        }
    )
    const balanceA = await utils._checkBalance([0, 666666666666], forSwap, tokenA)
    const balanceB = await utils._checkBalance([0, 666666666666], forSwap, tokenB)
    console.log('balanceA: ', balanceA)
    console.log('balanceB: ', balanceB)
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