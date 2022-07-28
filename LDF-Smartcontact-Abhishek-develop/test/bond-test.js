const { Provider } = require("@ethersproject/abstract-provider");
const { expect } = require("chai");
const { utils, providers, getDefaultProvider } = require("ethers");
const { ethers } = require("hardhat");

// steps to be followed before running this file.
// 1. change the owner address in .enc file.
// 2. check if your account has enough Lp tokens to deposit in liquidity bond. 
// 3. If there is no enough lp tokens in your account please ping me I will share some of it.
// 4. This test file should be tested in rinkeby test network only.

/**************************************Reserve bond******************************************** */

describe("Reserve Bond Contract", function() {
	let bond;
    const owner = process.env.OWNER;
    let LDFETH = process.env.LDFETH;
	let zeroAddress = "0x0000000000000000000000000000000000000000";
	let treasury;
	let ldfBondParking;
	let USDC;
	let native;
	let calculator;
	let lptoken;
	let provider;
	let block;
	let amount = 3000000000000000000n;
	let input = BigInt(100 * 10**6 * 10**18);

	it("Should deploy Bond Contract", async function() {

		const ldfToken = await ethers.getContractFactory("ldftoken");
		native = await ldfToken.deploy();
		console.log("Address of native token",native.address);

		const PToken = await ethers.getContractFactory("ldftoken");
		USDC = await PToken.deploy();
		console.log("Address of principal token", USDC.address);

		lptoken = await ethers.getContractAt("UniswapV2Pair", LDFETH);
        console.log("Address of lptoken", lptoken.address)

		const bondcalculator = await ethers.getContractFactory("LdfBondingCalculator");
		calculator = await bondcalculator.deploy(native.address);
		console.log("Address of calculator contract", calculator.address);

		const parking = await ethers.getContractFactory("ldfBondParking");
        ldfBondParking = await parking.deploy(native.address, "1", input);
        console.log("Address of ldfBondParking contract", ldfBondParking.address);

		const ldfTreasury = await ethers.getContractFactory("ldfTreasury");
        treasury = await ldfTreasury.deploy(native.address, USDC.address, lptoken.address, zeroAddress, ldfBondParking.address, "0");
        console.log("Address of treasury contract", treasury.address);

		const ldfbond = await ethers.getContractFactory("ldfBondDepository");
		bond = await ldfbond.deploy(native.address, USDC.address, treasury.address, zeroAddress);
		console.log("Address of bond contract", utils.getAddress(bond.address));

	});

	describe("Do all the required steps before interacting with bond contract", function() {

		it("Should be able to deposit native token and add treasury address into ldfbondparking contract", async function() {
			const approveAmount = await native.approve(ldfBondParking.address, "100000000000000000000000000");
	
			const depositAmount = await ldfBondParking.deposit("100000000000000000000000000", {
			gasLimit: 100000,
			});
			await depositAmount.wait();
	
			const totalsupply = await ldfBondParking.totalDeposited();

			const currenysupply = await ldfBondParking.CurrentSupply();
			console.log("currentsupply: ", currenysupply);

			console.log("Phase number and limit", await ldfBondParking.phaseLimit(1));
			
			await ldfBondParking.manage(treasury.address);
	
			expect(await totalsupply).to.equal("100000000000000000000000000");
		});

		it("Should be able to queue and toggle", async function() {
			const queueReserveDepositer = await treasury.queue("0", bond.address);
            await queueReserveDepositer.wait();

            const toggleReserveDepositer = await treasury.toggle("0", bond.address, zeroAddress);
            await toggleReserveDepositer.wait();
		});
	});

	describe("initialize bond, Deposit reserve and withdraw native", function() {

		it("Should Initialize bond terms and deposit", async function() {

			const initializeBondTerms = await bond.initializeBondTerms("300", "1", "160", "50", "100000000000000000000000", "0", {
				gasLimit: 10000000,
			});

			provider = providers.getDefaultProvider(process.env.RINKEBY_URL);
			block = await provider.getBlockNumber();
			console.log("Block number at the time of initializing Bond Terms", block);

			await USDC.approve(bond.address, amount);

			const beforeDeposit = await USDC.balanceOf(owner);
			const balance = parseFloat(beforeDeposit);
			console.log("Balance of the owner before deposit", beforeDeposit);

			if(balance >= amount) {
				const bondDeposit = await bond.deposit(amount, "1203", owner, {
					gasLimit: 10000000,
				});
				await bondDeposit.wait();

				console.log("Deposited amount: ", amount);

				const afterDeposit = await USDC.balanceOf(owner);
				console.log("Balance of the owner after deposit", afterDeposit);

				expect(beforeDeposit).to.equal(afterDeposit.add(amount));
			} else {
				console.log("insufficient balance in user account");
			}
		});

		it("Should able to with draw the ldf token", async function() {
			const info = await bond.bondInfo(owner);
			// console.log(info);

			const beforeWithdraw = await native.balanceOf(owner);
			console.log("Balance of the owner before withdraw", beforeWithdraw);

			const withdraw = await bond.redeem(owner);
			const donewithdraw = await withdraw.wait();
			// console.log(donewithdraw);
			// console.log(donewithdraw.events?.filter((x) => {return x.event == "BondRedeemed"}));

			const afterWithdraw = await native.balanceOf(owner);
			console.log("Balance of the owner after withdraw", afterWithdraw);
		});
	});

	describe("All view Function", function() {

		it("Should be able to check DebtDecay", async function() {
			block = await provider.getBlockNumber();
			console.log("Block number at the time of DebtDecay", block);

			const DebtDecay = await bond.debtDecay();
			console.log("DebtDecay: ", DebtDecay);
		});

		it("Should be able to check currentdebt", async function() {
			const CurrentDebt = await bond.currentDebt();
			console.log("CurrentDebt: ", CurrentDebt);
		});

		it("Should be able to check debtratio", async function() {
			const DebtRatio = await bond.debtRatio();
			console.log("debtRatio", DebtRatio);
		});

		it("Should be able to check bondPrice", async function() {
			const BondPrice = await bond.bondPrice();
			console.log("BondPrice: ", BondPrice);

			expect(await BondPrice).to.equal("160");
		});

		it("Should be able to check maxpayout", async function() {
			const MaxPayout = await bond.maxPayout();
			console.log("maximum payout: ", MaxPayout);
		});

		it("Should be able to check percentVestedFor of depositor", async function() {
			const PercentVestedFor = await bond.percentVestedFor(owner);
			console.log("PercentVestedFor: ", PercentVestedFor);
		});

		it("Should be able to check pendingPayoutFor of depositor", async function() {
			const PendingPayoutFor = await bond.pendingPayoutFor(owner);
			console.log("PendingPayoutFor: ", PendingPayoutFor);
		});
	});
});

/**************************************Liquidity bond******************************************** */

describe("Liquidity Bond Contract", function() {
	let bond;
	const owner = process.env.OWNER;
    let LDFETH = process.env.LDFETH;
	let zeroAddress = "0x0000000000000000000000000000000000000000";
	let treasury;
	let ldfBondParking;
	let USDC;
	let native;
	let calculator;
	let lptoken;
	let provider;
	let block;
	let amount = 3000000000000000000n;
	let input = BigInt(100 * 10**6 * 10**18);

	it("Should deploy Bond Contract", async function() {

		const ldfToken = await ethers.getContractFactory("ldftoken");
		native = await ldfToken.deploy();
		console.log("Address of native token",native.address);

		const PToken = await ethers.getContractFactory("ldftoken");
		USDC = await PToken.deploy();
		console.log("Address of principal token", USDC.address);

		lptoken = await ethers.getContractAt("UniswapV2Pair", LDFETH);
        console.log("Address of lptoken", lptoken.address)

		const bondcalculator = await ethers.getContractFactory("LdfBondingCalculator");
		calculator = await bondcalculator.deploy(native.address);
		console.log("Address of calculator contract", calculator.address);

		const parking = await ethers.getContractFactory("ldfBondParking");
        ldfBondParking = await parking.deploy(native.address, "1", input);
        console.log("Address of ldfBondParking contract", ldfBondParking.address);

		const ldfTreasury = await ethers.getContractFactory("ldfTreasury");
        treasury = await ldfTreasury.deploy(native.address, USDC.address, lptoken.address, zeroAddress, ldfBondParking.address, "0");
        console.log("Address of treasury contract", treasury.address);

		const ldfbond = await ethers.getContractFactory("ldfBondDepository");
		bond = await ldfbond.deploy(native.address, lptoken.address, treasury.address, calculator.address);
		console.log("Address of bond contract", utils.getAddress(bond.address));

	});

	describe("Do all the required steps before interacting with bond contract", function() {

		it("Should be able to deposit native token and add treasury address into ldfbondparking contract", async function() {
			const approveAmount = await native.approve(ldfBondParking.address, "100000000000000000000000000");
	
			const depositAmount = await ldfBondParking.deposit("100000000000000000000000000", {
			gasLimit: 100000,
			});
			await depositAmount.wait();
	
			const totalsupply = await ldfBondParking.totalDeposited();

			await ldfBondParking.manage(treasury.address);
	
			expect(await totalsupply).to.equal("100000000000000000000000000");
		});

		it("Should be able to queue and toggle", async function() {
			const queueLiquidityDepositer = await treasury.queue("3", bond.address);
            await queueLiquidityDepositer.wait();

            const toggleLiquidityDepositer = await treasury.toggle("3", bond.address, calculator.address);
            await toggleLiquidityDepositer.wait();

			const queueLiquidityToken = await treasury.queue("4", lptoken.address);
            await queueLiquidityToken.wait();

            const toggleLiquidityToken = await treasury.toggle("4", lptoken.address, calculator.address);
            await toggleLiquidityToken.wait();

			const queueLiquidityToken1 = await treasury.queue("4", lptoken.address);
            await queueLiquidityToken1.wait();

            const toggleLiquidityToken1 = await treasury.toggle("4", lptoken.address, calculator.address);
            await toggleLiquidityToken1.wait();
		});
	});

	describe("initialize bond, Deposit reserve and withdraw native", function() {

		it("Should Initialize bond terms and deposit", async function() {

			const initializeBondTerms = await bond.initializeBondTerms("300", "1", "160", "50", "100000000000000000000000", "0", {
				gasLimit: 10000000,
			});

			provider = providers.getDefaultProvider(process.env.RINKEBY_URL);
			block = await provider.getBlockNumber();
			console.log("Block number at the time of initializing Bond Terms", block);

			await lptoken.approve(bond.address, amount);

			const beforeDeposit = await lptoken.balanceOf(owner);
			const balance = parseFloat(beforeDeposit);
			console.log("beforeDeposit:", balance);

			if(amount <= balance) {
				const bondDeposit = await bond.deposit(amount, "1203", owner, {
					gasLimit: 10000000,
				});
				await bondDeposit.wait();

			 	console.log("Deposited amount: ", amount);
				const afterDeposit = await lptoken.balanceOf(owner);
				console.log("Balance of the owner after deposit", afterDeposit);
				expect(beforeDeposit).to.equal(afterDeposit.add(amount));
			} else {
				console.log("insufficient balance in user account");
			}
		});

		it("Should able to withdraw the ldf token", async function() {
			const info = await bond.bondInfo(owner);
			// console.log(info);

			const beforeWithdraw = await native.balanceOf(owner);
			console.log("Balance of the owner before withdraw", beforeWithdraw);

			const withdraw = await bond.redeem(owner,  {
				gasLimit: 10000000,
			});
			await withdraw.wait();

			// console.log(donewithdraw.events?.filter((x) => {return x.event == "BondRedeemed"}));

			const afterWithdraw = await native.balanceOf(owner);
			console.log("Balance of the owner after withdraw", afterWithdraw);
		});
	});

	describe("All view Function", function() {

		it("Should be able to check DebtDecay", async function() {
			block = await provider.getBlockNumber();
			console.log("Block number at the time of DebtDecay", block);

			const DebtDecay = await bond.debtDecay();
			console.log("DebtDecay: ", DebtDecay);
		});

		it("Should be able to check currentdebt", async function() {
			const CurrentDebt = await bond.currentDebt();
			console.log("CurrentDebt: ", CurrentDebt);
		});

		it("Should be able to check debtratio", async function() {
			const DebtRatio = await bond.debtRatio();
			console.log("debtRatio: ", DebtRatio);
		});

		it("Should be able to check bondPrice", async function() {
			const BondPrice = await bond.bondPrice();
			console.log("BondPrice: ", BondPrice);

			expect(await BondPrice).to.equal("160");
		});

		it("Should be able to check maxpayout", async function() {
			const MaxPayout = await bond.maxPayout();
			console.log("maximum payout: ", MaxPayout);
		});

		it("Should be able to check percentVestedFor of depositor", async function() {
			const PercentVestedFor = await bond.percentVestedFor(owner);
			console.log("PercentVestedFor: ", PercentVestedFor);
		});

		it("Should be able to check pendingPayoutFor of depositor", async function() {
			const PendingPayoutFor = await bond.pendingPayoutFor(owner);
			console.log("PendingPayoutFor: ", PendingPayoutFor);
		});
	});
});