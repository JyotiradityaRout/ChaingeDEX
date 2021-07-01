const hre = require("hardhat");
const utils = require('./utils/utils');

async function main() {
    const [owner, forSwap] = await hre.ethers.getSigners();
    const amountA = utils.addZero(1, 18);
    const amountB = utils.addZero(45, 17);
    const timer = parseInt(Date.now() / 1000)

    const chaingeSwapRouter = await hre.ethers.getContractAt('ChaingeSwap', "0xC2D5F1C13e2603624a717409356DD48253f17319", owner);

    console.log('chaingeSwapRouter', chaingeSwapRouter.address);

    await chaingeSwapRouter.addLiquidity(
     '0xaD60cee051579E1143e3DC425573f57Ac05A1315', '0x6aa9cd608F9984C3122dA1b94dEB6930c9AaE364',
     '100000000000000000000', '400000000000000000000', 
     '100000000000000000000', '400000000000000000000',
     '0xdf1FAcbC27E16F2189E35eb652564502e75Ebf77',
     '9999999999999',
     ['1623062069','666666666666', '1623062069','666666666666']
     )

    console.log('addLiqiudity 成功啊!')
    
    const chaingeDexPair = await hre.ethers.getContractAt('ChaingeDexPair', "0x72D43d64a4079ADb072e36945c10F34d6d36F825", owner);

    const balance = await chaingeDexPair.balanceOf('0xdf1FAcbC27E16F2189E35eb652564502e75Ebf77');

    console.log('Liqiudity Token:',balance);
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