const chai = require('chai');
const expect = chai.expect;
const BN = require('bignumber.js');
chai.use(require('chai-bignumber')(BN));
// Import utilities from Test Helpers
const truffleAssert = require('truffle-assertions');


const Nexus = artifacts.require('Nexus');
const IUniswapV2Router02 = artifacts.require('IUniswapV2Router02');

const uniswapRouterAddress = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3"; // Testnet
// const uniswapRouterAddress ="0x10ED43C718714eb63d5aA57B78B54704E256024E" ; // Mainnet


contract("Nexus", function ([owner, vip1, vip2, vip3, other, bot]) {
    const ethLiqInitial = new BN("10000000000000000");
    const nexusLiqInitial = new BN("10000000000000000000000");


    var vips = [vip1, vip2, vip3];

    it('Contract Deploy', async function () {
        // Deploy the nexus contract and get the swap interface
        this.router = await IUniswapV2Router02.at(uniswapRouterAddress);
        this.nexus = await Nexus.new(uniswapRouterAddress, 60, { from: owner });
        console.log(this.nexus.address)
        // Prepare the contract for pre-sale and check the maximum amount and state
        await this.nexus.prepareForPreSale({ from: owner });

        expect(await this.nexus.isInPresale(), "State must me presale").to.equal(true);
        // add the vips
        await this.nexus.addToVIP(vips, { from: owner })
        vips.forEach(async (vip) => {
            expect(await this.nexus.isVIP(vip, { from: owner })).to.equal(true);
        })
        // add botlist
        await this.nexus.addToantibotlist([bot], { from: owner })
        expect(await this.nexus.isAntibotListed(bot, { from: owner })).to.equal(true);

        // Prepare the contract for pre-sale and check the maximum amount and state
        await this.nexus.approve(this.router.address, new BN("2000000000000000000000000"), { from: owner })
        await this.router.addLiquidityETH(
            this.nexus.address,
            nexusLiqInitial,
            nexusLiqInitial,
            ethLiqInitial,
            owner,
            Math.floor(Date.now() / 1000) + 60 * 10, { from: owner, value: ethLiqInitial });

    })

    it('Buy before presale ends', async function () {


        await truffleAssert.reverts(
            this.router.swapExactETHForTokensSupportingFeeOnTransferTokens(
                0,
                [await this.router.WETH(), this.nexus.address],
                vip1,
                Math.floor(Date.now() / 1000) + 60 * 10,
                { from: vip1, value: new BN("1000000000000000") }),

            "Pancake: TRANSFER_FAILED",
        );


    });

    it('Public Sale With VIP list', async function () {

        await this.nexus.afterPreSale({ from: owner });
        console.log(await this.nexus.marketStatus())

        // expect(await this.nexus.marketStatus()).to.equal((false, true, true, false));

        await truffleAssert.passes(
            this.router.swapExactETHForTokensSupportingFeeOnTransferTokens(
                0,
                [await this.router.WETH(), this.nexus.address],
                vip1,
                Math.floor(Date.now() / 1000) + 60 * 10,
                { from: vip1, value: new BN("1000000000000000") })
        )

        await truffleAssert.reverts(
            this.router.swapExactETHForTokensSupportingFeeOnTransferTokens(
                0,
                [await this.router.WETH(), this.nexus.address],
                other,
                Math.floor(Date.now() / 1000) + 60 * 10,
                { from: other, value: new BN("1000000000000000") }),

            "Pancake: TRANSFER_FAILED",
        );

        console.log("Waiting")
        await new Promise(resolve => setTimeout(resolve, 1000 * 80));
        console.log("Done Waiting")
        await truffleAssert.passes(
            this.router.swapExactETHForTokensSupportingFeeOnTransferTokens(
                0,
                [await this.router.WETH(), this.nexus.address],
                other,
                Math.floor(Date.now() / 1000) + 60 * 10,
                { from: other, value: new BN("1000000000000000") })
        )

    });
    it('Time Between buys and sells', async function () {
        console.log("Waiting 10 seconds")
        await new Promise(resolve => setTimeout(resolve, 1000 * 10));
        console.log("Done Waiting")
        let pass = truffleAssert.passes(
            this.router.swapExactETHForTokensSupportingFeeOnTransferTokens(
                0,
                [await this.router.WETH(), this.nexus.address],
                other,
                Math.floor(Date.now() / 1000) + 60 * 10,
                { from: other, value: new BN("1000000000000000") })
        )

        let revert = truffleAssert.reverts(
            this.router.swapExactETHForTokensSupportingFeeOnTransferTokens(
                0,
                [await this.router.WETH(), this.nexus.address],
                other,
                Math.floor(Date.now() / 1000) + 60 * 10,
                { from: other, value: new BN("2000000000000000") })
        );
        await pass;
        await revert;
        // Use large integer comparisons
        // expect(await this.nexus.name( )).to.equal("Nexus");
    });

    it('Aintibot list ', async function () {

        await truffleAssert.reverts(
            this.router.swapExactETHForTokensSupportingFeeOnTransferTokens(
                0,
                [await this.router.WETH(), this.nexus.address],
                bot,
                Math.floor(Date.now() / 1000) + 60 * 10,
                { from: bot, value: new BN("1000000000000000") }),

            "Pancake: TRANSFER_FAILED",
        );
        // Use large integer comparisons
        // expect(await this.nexus.name( )).to.equal("Nexus");
    });
})
