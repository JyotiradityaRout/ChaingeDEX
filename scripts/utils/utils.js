const hre = require("hardhat");
const { utils } = require("ethers");

async function sleep() {
    return new Promise(function (res, rej) {
        setTimeout(() => {
            res()
        }, 1)
    })
}

module.exports.mint = async (forLiquidity, forSwap, utils, params) => {
    // signer发合约的地址
    console.log('\x1B[37m', 'forLiquidity:', forLiquidity.address)
    console.log('forSwap:', forSwap.address)

    console.log('-------------- frc758 --------------')
    const { tokenA, tokenB, tokenC } = await utils.frc758([forLiquidity, forSwap], params)
    const mint = await tokenA.timeBalanceOf(forLiquidity.address, params.startTime, params.endTime); // startTime 必须大于当前时间
    const mint2 = await tokenB.timeBalanceOf(forLiquidity.address, params.startTime, params.endTime); // startTime 必须大于当前时间

    console.log('-------------- frc758 --------------')
    return { tokenA, tokenB, tokenC }
}

module.exports.autoInit = async (forLiquidity, forSwap, utils, params) => {
    const { tokenA, tokenB } = await utils.mint(forLiquidity, forSwap, utils, params)

    await sleep()
    const { uniswapV2Factory } = await utils.factory(forLiquidity)

    const pair = await utils.createPair(uniswapV2Factory, tokenA, tokenB, params)

    await sleep()
    const uniRouter = await utils.router(uniswapV2Factory.address, tokenA.address)

    await sleep()
    await utils.approve(uniRouter.address, tokenA, tokenB)

    await sleep()

    const res = await utils.addLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, params)

    const bal = await tokenA.timeBalanceOf(forLiquidity.address, params.startTime, params.endTime); // startTime 必须大于当前时间
    console.log('tokenA balance', parseInt(bal._hex));

    const bal2 = await tokenB.timeBalanceOf(forLiquidity.address, params.startTime, params.endTime); // startTime 必须大于当前时间
    console.log('tokenB balance', parseInt(bal2._hex));


    await sleep()
    // await utils.swap(forSwap, uniRouter, tokenA.address, tokenB.address, params)
    await utils.removeLiquidity(forSwap, uniRouter, tokenA.address, tokenB.address, params)
    const bal3 = await tokenA.timeBalanceOf(forSwap.address, params.startTime, params.endTime); // startTime 必须大于当前时间
    console.log('tokenA balance', parseInt(bal3._hex));

    const bal4 = await tokenB.timeBalanceOf(forSwap.address, params.startTime, params.endTime); // startTime 必须大于当前时间
    console.log('tokenB balance', parseInt(bal4._hex));


    console.log('-------------- remove后 --------------')
    console.log(`当前tokenA `, +bal3 + +bal)
    console.log('tokenA差值', +mint - +bal3 + +bal)
    console.log(`当前tokenB `, +bal2 + +bal4)
    console.log('tokenB差值', +mint2 - +bal2 + +bal4)
    console.log('-------------- remove后 --------------')

    return { tokenA, tokenB }
}


module.exports.frc758 = async (_s, config) => {
    const signers = _s[0];
    const forSwap = _s[1];

    const FRC758 = await hre.ethers.getContractFactory("ChaingeTestToken");

    const tokenA = await FRC758.deploy("TokenA", "F1", 18);
    await tokenA.deployed();

    await sleep()
    await tokenA.mintTimeSlice(signers.address, config.amountA +'00000000', config.startTime, config.endTime)
    // await tokenA.mintTimeSlice(forSwap.address, config.amountA, config.startTime, config.endTime)
    await sleep()
    console.log('toeknA address:', tokenA.address)
    const bal = await tokenA.timeBalanceOf(signers.address, config.startTime, config.endTime); // startTime 必须大于当前时间
    console.log('tokenA balance:', parseInt(bal._hex))

    await sleep()

    const tokenB = await FRC758.deploy("TokenB", "F2", 18);
    await tokenB.deployed();
    await sleep()
    await tokenB.mintTimeSlice(signers.address, config.amountB  + '000000', config.startTime, config.endTime)
    // await tokenB.mint(forSwap.address, config.amountB)
    console.log('toeknB address:', tokenB.address)
    await sleep()
    const bal2 = await tokenB.timeBalanceOf(signers.address, config.startTime, config.endTime); // startTime 必须大于当前时间
    console.log('tokenB balance:', parseInt(bal2._hex))

    const tokenC = await FRC758.deploy("TokenB", "F3", 18);
    await tokenC.deployed();
    await sleep()
    await tokenC.mintTimeSlice(signers.address, config.amountB  + '000000000000000000', config.startTime, config.endTime)
    // await tokenB.mint(forSwap.address, config.amountB)
    console.log('toeknC address:', tokenC.address)
    await sleep()
    const bal3 = await tokenC.timeBalanceOf(signers.address, config.startTime, config.endTime); // startTime 必须大于当前时间
    console.log('tokenC balance:', parseInt(bal3._hex))

    return {
        tokenA,
        tokenB,
        tokenC
    }
}

module.exports.depErc20 = async () => {
    const TokenERC20 = await hre.ethers.getContractFactory("TokenERC20");
    const tokenA = await TokenERC20.deploy(18, "TokenA", "TOA");
    await tokenA.deployed();
    await sleep()
    console.log('tokenA address', tokenA.address);
    await tokenA.mint(18000000000)
    await sleep()
    const tokenB = await TokenERC20.deploy(18, "TokenB", "TOB");
    await tokenB.deployed();
    await sleep()
    await tokenB.mint(18000000000)
    console.log('toeknB address', tokenB.address)

    return {
        tokenA,
        tokenB
    }
}

module.exports.factory = async (signers) => {
    const UniswapV2Factory = await hre.ethers.getContractFactory("ChaingeDexFactory");
    const uniswapV2Factory = await UniswapV2Factory.deploy(signers.address);
    await uniswapV2Factory.deployed();

    console.log('uniswapV2Factory', uniswapV2Factory.address)
    await sleep()
    return {
        uniswapV2Factory: uniswapV2Factory
    }
}


module.exports.createPair = async (factory, tokenA, tokenB, config) => {
    console.log('start createPair')
    const pair = await factory.createPair(tokenA.address, tokenB.address, [config.startTime, config.endTime, config.startTime, config.endTime]); // 创建个1617212453 到永远的和 1627212453 到永远的。
    console.log('end createPair')
    await sleep()
    return factory.getPair(tokenA.address, tokenB.address, [config.startTime, config.endTime, config.startTime, config.endTime]);
}

module.exports.router = async (factory, weth) => {
    // 路由合约
    const Router = await hre.ethers.getContractFactory("ChaingeSwap");
    const uniRouter = await Router.deploy(factory);
    await uniRouter.deployed();
    console.log("Router deployed to:", uniRouter.address);
    return uniRouter
}

module.exports.approve = async (routerAddress, tokenA, tokenB, tokenC) => {
    // console.log("approve start");
    // 给路由合约授权
    await tokenA.approve(routerAddress, '1000000000000000000000000000')
    // console.log("approve end");
    await sleep()
    // console.log("approve start");
    await tokenB.approve(routerAddress, '1000000000000000000000000000')
    // console.log("approve end");
    await sleep()
    await tokenC.approve(routerAddress, '1000000000000000000000000000000000')
    console.log('C approve 成功:', tokenC.address, routerAddress);
}

module.exports.addLiquidity = async (signers, uniRouter, addressA, addressB, config) => {
    console.log('-------------- addLiquidity --------------')
     
    const res = await uniRouter.addLiquidity(
        addressA,
        addressB,
        config.amountADesired,
        config.amountBDesired,
        config.amountAMin,
        config.amountBMin,
        signers.address,
        9999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime]
    )
    console.log('-------------- addLiquidity --------------')
    return res
}

module.exports.removeLiquidity = async (signers, uniRoute, addressA, addressB, liq, config) => {
    console.log('-------------- removeLiquidity --------------')
    const res = await uniRoute.removeLiquidity(
        addressA,
        addressB,
        liq,
        config.amountAMin,
        config.amountBMin,
        signers.address,
        9999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime]
    )
    console.log('-------------- removeLiquidity --------------')
    return res
}

module.exports.swap = async (signers, uniRouter, addressA, addressB, config) => {
    console.log('-------------- swap --------------')
    const swapResult = await uniRouter.swapTokensForExactTokens(
        config.amountOut,
        config.amountInMax,
        [addressA, addressB],
        signers.address,
        999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime]
    )
    console.log('-------------- swap --------------')
    return swapResult
}

module.exports.swap2= async (signers, uniRouter, addressA, addressB, config) => {
    // console.log('-------------- swap --------------')
    // const swapResult = await uniRouter.swapExactTokensForTokens(
    //     '10000000000000000000',
    //     '1361156',
    //     [addressA, addressB],
    //     signers.address,
    //     999999999999,
    //     [config.startTime, config.endTime, config.startTime, config.endTime]
    // )
    // console.log('-------------- swap --------------')

    console.log('-------------- swap --------------')

    const swapResult = await uniRouter.swapExactTokensForTokens(
        '113344700',
        '124222882264606726329120',
        [addressB, addressA],
        signers.address,
        999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime]
    )
    console.log('-------------- swap --------------')
    return swapResult
}

module.exports.swap3 = async (signers, uniRouter, addressA, addressB, addressC, config) => {

    console.log('-------------- swap3 --------------, ', config)

    const swapResult = await uniRouter.swapExactTokensForTokens(
        '136115600000000',
        '4989',
        [addressA, addressB, addressC],
        signers.address,
        999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime, config.startTime, config.endTime]
    )
    console.log('-------------- swap3 --------------')
    return swapResult
}

// swapTokensForExactTokens

module.exports.swap4 = async (signers, uniRouter, addressA, addressB, addressC, config) => {

    console.log('-------------- swap4 --------------, ', config)
    const swapResult = await uniRouter.swapTokensForExactTokens(
        '113344700',
        '124222882264606726329120',
        [addressA, addressB, addressC],
        signers.address,
        999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime, 
            config.startTime, config.endTime
        ]
    )
    console.log('-------------- swap4  --------------')
    return swapResult
}


module.exports.checkBalance = async function checkBalance(signers, tokenA, tokenB, config) {
    const balanceA = await tokenA.timeBalanceOf(signers.address, config.startTime, config.endTime)
    const balanceB = await tokenB.timeBalanceOf(signers.address, config.startTime, config.endTime)

    console.log('A:', parseInt(balanceA._hex), 'B:', parseInt(balanceB._hex));
    return [parseInt(balanceA._hex), parseInt(balanceB._hex)]
}

module.exports.addZero = (_p, _l) => {
    return _p + new Array(_l).fill(0).join('')
}

module.exports._checkBalance = async (timer = config.checkTImer, signers, token) => {
    const balance = await token.timeBalanceOf(signers.address, timer[0], timer[1])
    console.log(signers)
    return parseInt(balance._hex)
}

module.exports.getK = async (afterRemoveLiquidity) => {
    const removeDeltaA = afterRemoveLiquidity[0] - afterAddLiquidity[0]
    const removeDeltaB = afterRemoveLiquidity[1] - afterAddLiquidity[1]
    const _k = removeDeltaA * removeDeltaB * Math.pow(deltaA / removeDeltaA, 2)
    return _k
}

module.exports.feeToBalance = async (pair, signersAddress, config) => {
    // console.log('feeToAddress', feeToAddress)
    const pairObj = await hre.ethers.getContractAt('ChaingeDexPair', pair, signersAddress)
    // const otherBalance = await pairObj.timeBalanceOf(feeToAddress, 1619395996, 666666666666)
    // console.log('feeToBalance ', parseInt(otherBalance._hex));
    const signersBalance = await pairObj.timeBalanceOf(signersAddress.address, config.startTime, config.endTime)
    return parseInt(signersBalance._hex)
}