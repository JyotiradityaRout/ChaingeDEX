const hre = require("hardhat");
const utils = require('./utils/utils');


const config = {
    startTime: '1625144203',
    endTime: '18446744073709551615',
    TFStartTime: '1627747200',
    TFEndTime: '18446744073709551615'
}

async function main() {
    const [signers] = await hre.ethers.getSigners();

    console.log(signers.address);

    // const tokenA = await getToken('0xd5DAa7CE7E3e0094a97Ec811c4fB39570aec39Cd', signers);
    const tokenA = await createToken();
    await sleep()
    await tokenA.mint(signers.address, '1000000000000000000000');
    await sleep()
    await tokenA.mintSlice(signers.address, '1000000000000000000000', config.TFStartTime, config.TFEndTime)

    // const bal = await tokenA.timeBalanceOf(signers.address, config.TFStartTime, config.TFEndTime); // startTime 必须大于当前时间
    // console.log('tokenA balance:', parseInt(bal._hex))
    await sleep()

    // const tokenB = await getToken('0x3f36fF84958b0473925Afe368Cd25A9c23fA56cF', signers);
    const {uniRouter, pair} = await deployDEX(signers, tokenA, tokenA);
    await sleep()
    await approve(tokenA, uniRouter.address, '10000000000000000000000000000000000000000');
    // await approve(tokenB, uniRouter.address, '1000000000000000000000000000000');
    await sleep()


    // const slice = await tokenA.sliceOf(signers.address);

    // console.log('slice:',slice.map((val)=> {
    //     return val.map((v)=> {
    //         return parseInt(v._hex)
    //     })
    // }));

    // await uniRouter.addLiquidity(
    //     tokenA.address,
    //     tokenA.address,
    //     '1000000000000000000',
    //     '2000000000000000000',
    //     '1000000000000000000',
    //     '2000000000000000000',
    //     signers.address,
    //     9999999999999,
    //     [config.startTime, config.endTime, config.TFStartTime, config.TFEndTime]
    // );

    

    await uniRouter.addLiquidity(
        tokenA.address,
        tokenA.address,
        '2010579449',
        '696005681',
        '2010579449',
        '696005681',
        signers.address,
        9999999999999,
        [config.TFStartTime, config.TFEndTime,config.startTime, config.endTime]
    );

    // await uniRouter.addLiquidity(
    //     tokenA.address,
    //     tokenA.address,
    //     '2000000000000000000',
    //     '1000000000000000000',
    //     '2000000000000000000',
    //     '1000000000000000000',
    //     signers.address,
    //     9999999999999,
    //     [config.TFStartTime, config.TFEndTime,config.startTime, config.endTime]
    // );
    await sleep()
    const pairObj = await hre.ethers.getContractAt("ChaingeDexPair", pair, signers);

    const lpBalance = await pairObj.balanceOf(signers.address);
    console.log('lpBalance', parseInt(lpBalance._hex));
    await approve(pairObj, uniRouter.address, '100000000000000000000000000000000000000000000');

    // const balA0 = await tokenA.balanceOf(signers.address);
    // console.log('删除之前 现货:', parseInt(balA0._hex));

    // const balB0 = await tokenA.timeBalanceOf(signers.address, config.TFStartTime,config.TFEndTime);
    // console.log('删除之前 期货:', parseInt(balB0._hex));

    // await uniRouter.removeLiquidity(
    //     tokenA.address,
    //     tokenA.address,
    //     '1414213562373093100',
    //     '1999999999999995830',
    //     '999999999999997915',
    //     signers.address,
    //     9999999999999,
    //     [config.TFStartTime, config.TFEndTime,config.startTime, config.endTime]
    // )

    await sleep()
    const balA = await tokenA.balanceOf(signers.address);
    console.log('交易之前 现货:', parseInt(balA._hex));

    const balB = await tokenA.timeBalanceOf(signers.address, config.TFStartTime,config.TFEndTime);
    console.log('交易之前 期货:', parseInt(balB._hex));

    // const slice1 = await tokenA.sliceOf(pair);

    // console.log('pair slice:',slice1.map((val)=> {
    //     return val.map((v)=> {
    //         return parseInt(v._hex)
    //     })
    // }));

    await uniRouter.swapExactTokensForTokens(
        '5775780',
        '1890222',
        [tokenA.address,  tokenA.address],
        signers.address,
        999999999999,
        [config.TFStartTime, config.TFEndTime, config.startTime, config.endTime]
    );

    await sleep()
    const balA1 = await tokenA.balanceOf(signers.address);
    console.log('交易之后 现货:', parseInt(balA1._hex));

    const balB1 = await tokenA.timeBalanceOf(signers.address, config.TFStartTime,config.TFEndTime);
    console.log('交易之后 期货:', parseInt(balB1._hex));

    console.log('拿期货买现货之后，花费了期货', parseInt(balB._hex) - parseInt(balB1._hex), '得到的现货:', parseInt(balA1._hex) - parseInt(balA._hex));
}

async function getToken(address, signers) {
    const FRC758 = await hre.ethers.getContractAt("ChaingeTestToken", address, signers);
    return FRC758;
}
async function createToken() {
    const FRC758 = await hre.ethers.getContractFactory("ChaingeTestToken");
    const tokenA = await FRC758.deploy("TokenA", "F1", 18);
    await tokenA.deployed();
    return tokenA;
}


async function approve(token, address, amount) {
    await token.approve(address, amount);
}

async function deployDEX(signers, tokenA, tokenB) {
    const UniswapV2Factory = await hre.ethers.getContractFactory("ChaingeDexFactory");
    const uniswapV2Factory = await UniswapV2Factory.deploy(signers.address);
    await uniswapV2Factory.deployed();

    console.log('Factory:', uniswapV2Factory.address);

    console.log('start createPair')
    await uniswapV2Factory.createPair(tokenA.address, tokenB.address, [ config.TFStartTime, config.TFEndTime, config.startTime, config.endTime]); // 创建个1617212453 到永远的和 1627212453 到永远的。
    console.log('end createPair')
    await sleep()
    const pair = await uniswapV2Factory.getPair(tokenA.address, tokenB.address, [ config.TFStartTime, config.TFEndTime, config.startTime, config.endTime]);

    const Router = await hre.ethers.getContractFactory("ChaingeSwap");
    const uniRouter = await Router.deploy(uniswapV2Factory.address);
    await uniRouter.deployed();
    console.log("Router deployed to:", uniRouter.address);
    return {uniRouter, pair}
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
        }, 1)
    })
}
module.exports.main = main