const { expect } = require("chai");
const hre = require("hardhat");
const utils = require('../scripts/utils/utils');


describe("FRC758", async function () {
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
        amountOut: utils.addZero(1, 10),
        amountInMax: utils.addZero(4, 10),
        // removeLiquidity
        // liquidity: utils.addZero(1, 12),
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
    // 1000是最小流通量
    const liq = Math.sqrt(deltaA * deltaB) - 1000

    await utils.removeLiquidity(forLiquidity, uniRouter, tokenA.address, tokenB.address, utils.addZero(1, 12), config)
    const afterRemoveLiquidity = await utils.checkBalance(forLiquidity, tokenA, tokenB, config)
    const removeDeltaA = afterRemoveLiquidity[0] - afterAddLiquidity[0]
    const removeDeltaB = afterRemoveLiquidity[1] - afterAddLiquidity[1]
    const _k = removeDeltaA * removeDeltaB * Math.pow(deltaA / removeDeltaA, 2)


    it('liq', async () => {
        await expect(_k).to.equal(k);

    })
})