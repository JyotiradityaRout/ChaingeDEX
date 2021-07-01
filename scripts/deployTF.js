const hre = require("hardhat");
const utils = require('./utils/utils');


const config = {
    startTime: '1619395996',
    endTime: '18446744073709551615'
}

async function main() {
    const [signers] = await hre.ethers.getSigners();
    const tokenA = await getToken();
    const tokenB = await getToken();

    const {router} = await deployDEX();

    await approve(tokenA, router.address, '1000000000000000000000000000000');

    await router.addLiquidity(
        tokenA.address,
        tokenB.address,
        '10000000000000000000000',
        '100000000000000000000',
        '10000000000000000000000',
        '100000000000000000000',
        signers.address,
        9999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime]
    );

    await router.swapExactTokensForTokens(
        '1361156',
        '8304179445960657795',
        [addressB, addressA],
        signers.address,
        999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime]
    );
}

async function getToken(address) {
    const FRC758 = await hre.ethers.getContractAt("FRC758", address);
    return FRC758;
}

async function approve(token, address, amount) {
    await token.approve(address, amount);
}

async function deployDEX() {
    const UniswapV2Factory = await hre.ethers.getContractFactory("ChaingeDexFactory");
    const uniswapV2Factory = await UniswapV2Factory.deploy(signers.address);
    await uniswapV2Factory.deployed();

    console.log('start createPair')
    await uniswapV2Factory.createPair(tokenA.address, tokenB.address, [config.startTime, config.endTime, config.startTime, config.endTime]); // 创建个1617212453 到永远的和 1627212453 到永远的。
    console.log('end createPair')
    await sleep()
    const pair = uniswapV2Factory.getPair(tokenA.address, tokenB.address, [config.startTime, config.endTime, config.startTime, config.endTime]);

    const Router = await hre.ethers.getContractFactory("ChaingeSwap");
    const uniRouter = await Router.deploy(factory);
    await uniRouter.deployed();
    console.log("Router deployed to:", uniRouter.address);
    return {uniRouter}
}


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