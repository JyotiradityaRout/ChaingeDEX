const config = require("../config");
const hre = require("hardhat");

async function sleep() {
    return new Promise(function (res, rej) {
        setTimeout(() => {
            res()
        }, 0)
    })
}

module.exports.mint = async (forLiquidity, forSwap, utils, params) => {
    const { startTime, endTime, amountA, amountB, amountADesired, amountBDesired, amountAMin, amountBMin, amountOut, amountInMax } = params;
    // signer发合约的地址
    console.log('\x1B[37m', 'forLiquidity:', forLiquidity.address)
    console.log('forSwap:', forSwap.address)

    console.log('-------------- frc758 --------------')
    const { tokenA, tokenB } = await utils.frc758([forLiquidity, forSwap], params)
    console.log('-------------- frc758 --------------')

    await sleep()
    const { uniswapV2Factory } = await utils.factory(forLiquidity)

    const pair = await utils.createPair(uniswapV2Factory, tokenA, tokenB, params)
    await sleep()
    const uniRouter = await utils.router(uniswapV2Factory.address, tokenA.address)

    await sleep()
    await utils.approve(uniRouter.address, tokenA, tokenB)

    console.log('-------------- addLiquidity --------------')
    await sleep()

    const res = await utils.addLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, params)

    const bal = await tokenA.balanceOf(forLiquidity.address); // startTime 必须大于当前时间
    console.log('tokenA balance', parseInt(bal._hex), parseInt(bal._hex).length);

    const bal2 = await tokenB.balanceOf(forLiquidity.address); // startTime 必须大于当前时间
    console.log('tokenB balance', parseInt(bal2._hex), parseInt(bal2._hex).length);

    console.log('res', res)
    console.log('-------------- addLiquidity --------------')

    // console.log('-------------- swap --------------')
    console.log('-------------- removeLiquidity --------------')
    
    await sleep()

    // await utils.swap(forSwap, uniRouter, tokenA.address, tokenB.address, params)
    await utils.removeLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, params)


    return { tokenA, tokenB }
}


module.exports.frc758 = async (_s, config) => {
    const signers = _s[0];
    const forSwap = _s[1];

    const FRC758 = await hre.ethers.getContractFactory("ChaingeTestToken");

    const tokenA = await FRC758.deploy("TokenA", "F1", 18);
    await tokenA.deployed();

    await sleep()
    await tokenA.mintTimeSlice(signers.address, config.amountA, config.startTime, config.endTime)
    await tokenA.mintTimeSlice(forSwap.address, config.amountA, config.startTime, config.endTime)
    console.log('toeknA address:', tokenA.address)
    const bal = await tokenA.balanceOf(signers.address); // startTime 必须大于当前时间
    console.log('tokenA balance:', parseInt(bal._hex))

    await sleep()

    const tokenB = await FRC758.deploy("TokenB", "F2", 18);
    await tokenB.deployed();
    await sleep()
    await tokenB.mintTimeSlice(signers.address, config.amountB, config.startTime, config.endTime)
    // await tokenB.mint(forSwap.address, config.amountB)
    console.log('toeknB address:', tokenB.address)
    const bal2 = await tokenB.balanceOf(signers.address); // startTime 必须大于当前时间
    console.log('tokenB balance:', parseInt(bal2._hex))

    return {
        tokenA,
        tokenB
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
    // console.log('start uniswapV2Factory')
    const UniswapV2Factory = await hre.ethers.getContractFactory("UniswapV2Factory");
    const uniswapV2Factory = await UniswapV2Factory.deploy(signers.address);
    await uniswapV2Factory.deployed();
    // console.log('end uniswapV2Factory')
    await sleep()
    return {
        uniswapV2Factory: uniswapV2Factory
    }
}


module.exports.createPair = async (factory, tokenA, tokenB, config) => {
    // console.log('start createPair')
    const pair = await factory.createPair(tokenA.address, tokenB.address, [config.startTime, config.endTime, config.startTime, config.endTime]); // 创建个1617212453 到永远的和 1627212453 到永远的。
    // console.log('end createPair')
    return pair
}

module.exports.router = async (factory, weth) => {
    // 路由合约
    const Router = await hre.ethers.getContractFactory("ChaingeSwap");

    const uniRouter = await Router.deploy(factory, weth);

    await uniRouter.deployed();
    console.log("Greeter deployed to:", uniRouter.address);
    return uniRouter
}

module.exports.approve = async (routerAddress, tokenA, tokenB) => {
    // console.log("approve start");
    // 给路由合约授权
    await tokenA.setApprovalForAll(routerAddress, true)
    // console.log("approve end");
    await sleep()
    // console.log("approve start");
    await tokenB.setApprovalForAll(routerAddress, true)
    // console.log("approve end");
}

module.exports.addLiquidity = async (signers, uniRouter, addressA, addressB, config) => {
    return await uniRouter.addLiquidity(
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
}

module.exports.removeLiquidity = async (signers, uniRoute, addressA, addressB, config) => {
    await uniRoute.removeLiquidity(
        addressA,
        addressB,
        config.liquidity,
        config.amountAMin,
        config.amountBMin,
        signers.address,
        9999999999999,
        [config.startTime, config.endTime, config.startTime, config.endTime]
    )
    console.log('removeLiquidity success')
}

module.exports.swap = async (signers, uniRouter, addressA, addressB, config) => {
    const swapResult = await uniRouter.swapTokensForExactTokens(
        config.amountOut,
        config.amountInMax,
        [addressA, addressB],
        signers.address,
        999999999999,
        [config.startTime, config.endTime]
    )
}

module.exports.checkBalance = async function checkBalance(timer = config.checkTImer, signers, tokenA, tokenB) {
    const balanceA = await tokenA.balanceOf(signers.address)
    const balanceB = await tokenB.balanceOf(signers.address)

    console.log('swap之后A 和 B ', parseInt(balanceA._hex), parseInt(balanceA._hex).length, parseInt(balanceB._hex), parseInt(balanceB._hex).length);
    return [parseInt(balanceA._hex), parseInt(balanceB._hex)].toString()
}

module.exports.addZero = (_p, _l) => {
    return _p + new Array(_l).fill(0).join('')
}

module.exports._checkBalance = async (timer = config.checkTImer, signers, token) => {
    const balance = await token.balanceOf(signers.address)
    return parseInt(balance._hex)
}