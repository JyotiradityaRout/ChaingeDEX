const { main } = require("../scripts/deployRouter2")
const { expect } = require("chai");
const hre = require("hardhat");

describe('DEX', function () {
    it("1", async function () {
        const { balanceA, balanceB } = await main()
        // console.log(balanceA, balanceB)
        // expect(balanceA).to.equal('100000000000000000000')
    })
})