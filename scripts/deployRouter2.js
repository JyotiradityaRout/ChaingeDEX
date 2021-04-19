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
            startTime: 0,
            endTime: 666666666666,
            amountA: utils.addZero(100000, 15),
            amountB: utils.addZero(100001, 15),
            amountADesired: utils.addZero(10, 15),
            amountBDesired: utils.addZero(100, 15),
            amountAMin: utils.addZero(9, 15),
            amountBMin: utils.addZero(4, 15),
            amountOut: utils.addZero(10, 15),
            amountInMax: utils.addZero(90, 15)
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