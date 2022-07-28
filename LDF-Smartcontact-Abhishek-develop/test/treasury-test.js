const { expect } = require("chai");
const { Contract } = require("ethers");
const { ethers } = require("hardhat");
const { any } = require("hardhat/internal/core/params/argumentTypes");

describe("Treasury Contract", function() {
    const owner = process.env.OWNER;
    let LDFETH = process.env.LDFETH;
    const zeroAddress = "0x0000000000000000000000000000000000000000";
    let native;
    let ldfBondParking;
    let treasury;
    let USDC;
    let calculator;
    let lptoken;

    it("Should be able to deploy treasury contract", async function() {
        const ldfToken = await ethers.getContractFactory("ldftoken");
		native = await ldfToken.deploy();
		console.log("Address of native token",native.address);
        
        const stableToken = await ethers.getContractFactory("ldftoken");
        USDC = await stableToken.deploy();
        console.log("Address of USDC Contract", USDC.address);

        lptoken = await ethers.getContractAt("UniswapV2Pair", LDFETH);
        console.log("lptoken", lptoken.address);

        const parking = await ethers.getContractFactory("ldfBondParking");
        ldfBondParking = await parking.deploy(native.address);
        console.log("Address of ldfBondParking contract", ldfBondParking.address);

        const bondCalculator = await ethers.getContractFactory("LdfBondingCalculator");
        calculator = await bondCalculator.deploy(native.address);
        console.log("Address of bond calculator contract", calculator.address);

        const ldfTreasury = await ethers.getContractFactory("ldfTreasury");
        treasury = await ldfTreasury.deploy(native.address, USDC.address, lptoken.address, zeroAddress, ldfBondParking.address, "0");
        console.log("Address of treasury contract", treasury.address);
    });

    it("Should be able to deposit native token into ldfbondparking contract", async function() {

        await native.approve(ldfBondParking.address, "175000000000000000000000000");
        const depositAmount = await ldfBondParking.deposit("175000000000000000000000000", {
        gasLimit: 100000,
        });
        await depositAmount.wait();

        const totalsupply = await ldfBondParking.totalDeposited();

        expect(await totalsupply).to.equal("175000000000000000000000000");
    });

    describe("Deposit and Manage functions", function() {

        it("Should be able to deposit reserve token into treasury", async () => {
            // console.log("Owner: - ", owner);
            const stableTokenBalanceBefore = await USDC.balanceOf(owner);
            console.log("USDC Token Balance Before Deposit", stableTokenBalanceBefore);

            await ldfBondParking.manage(treasury.address);

            const approveTreasury = await USDC.approve(treasury.address, "100000000000000000000");
            await approveTreasury.wait();

            const queueDepositer = await treasury.queue("0", owner);
            await queueDepositer.wait();

            const toggleDepositer = await treasury.toggle("0", owner, zeroAddress);
            await toggleDepositer.wait();

            const deposit = await treasury.deposit("100000000000000000000", USDC.address, "1000000000000000000", {
                gasLimit: 1000000,
            });
            await deposit.wait();

            const stableTokenBalanceAfter = await USDC.balanceOf(owner);
            console.log("USDC Token Balance After Deposit", stableTokenBalanceAfter);

            //Added by Rakesh - to check if token is deposited in treasury
            console.log("Token Balance in Treasury", await USDC.balanceOf(treasury.address));
            console.log("totalReserves in Treasury", await treasury.totalReserves());

            expect(await stableTokenBalanceBefore).to.equal(stableTokenBalanceAfter.add("100000000000000000000"));
        });

        it("Should be able to manage funds in treasury contract", async function() {
            const queueReserveManager = await treasury.queue("1", owner);
            await queueReserveManager.wait();

            const toggleReserveManager = await treasury.toggle("1", owner, zeroAddress, {
                gasLimit: 1000000,
            });
            await toggleReserveManager.wait();

            const usdcBalanceBefore = await USDC.balanceOf(owner);
            console.log("stable Token Balance Before Manage", usdcBalanceBefore);
            
            const manageTreasury = await treasury.manage(USDC.address, "10000000000000000000", {
                gasLimit: 10000000,
            });
            await manageTreasury.wait();

            const usdcBalanceAfter = await USDC.balanceOf(owner);
            console.log("stable Token Balance After Manage", usdcBalanceAfter);

            expect(await usdcBalanceBefore).to.equal(usdcBalanceAfter.sub("10000000000000000000"));
        });

        describe("Deposit and manage Lp token", async function() {

            it("Should be able to queue and toggle Lp token", async function() {
                await ldfBondParking.manage(treasury.address);

                const queueDepositer = await treasury.queue("3", owner);
                await queueDepositer.wait();

                const toggleDepositer = await treasury.toggle("3", owner, zeroAddress);
                await toggleDepositer.wait();

                const queueLpToken0 = await treasury.queue("4", LDFETH);
                await queueLpToken0.wait();

                const toggleLpToken0 = await treasury.toggle("4", LDFETH, calculator.address);
                await toggleLpToken0.wait();

                const queueLpToken1 = await treasury.queue("4", LDFETH);
                await queueLpToken1.wait();

                const toggleLpToken1 = await treasury.toggle("4", LDFETH, calculator.address);
                await toggleLpToken1.wait();

                await lptoken.approve(treasury.address, "1000000000000000000")
            });

            it("Should be able to deposit Lp token into treasury", async function() {
                const lpBalanceBefore = await lptoken.balanceOf(owner);
                console.log("Lp Token Balance Before Deposit", lpBalanceBefore);

                const deposit = await treasury.deposit("1000000000000000000", LDFETH, "11900593", {
                    gasLimit: 10000000,
                });
                await deposit.wait();

                const lpBalanceAfter = await lptoken.balanceOf(owner);
                console.log("Lp Token Balance After Deposit", lpBalanceAfter);

                expect(await lpBalanceBefore).to.equal(lpBalanceAfter.add("1000000000000000000")); 
            });

            it("Should be able to manage Lp token in treasury", async function() {
                const queueReserveManager = await treasury.queue("5", owner);
                await queueReserveManager.wait();
                
                const toggleReserveManager = await treasury.toggle("5", owner, zeroAddress, {
                gasLimit: 1000000,
                 });
                await toggleReserveManager.wait();

                const lpTokenBalanceBefore = await lptoken.balanceOf(owner);
                console.log("Lp Token Balance Before Manage", lpTokenBalanceBefore);
            
                const manageTreasury = await treasury.manage(lptoken.address, "100000000000000000", {
                    gasLimit: 10000000,
                });
                await manageTreasury.wait();

                console.log("totalReserves in Treasury", await treasury.totalReserves());
                const lpTokenBalanceAfter = await lptoken.balanceOf(owner);
                console.log("Lp Token Balance After Manage", lpTokenBalanceAfter);
            });
        });
    });
});