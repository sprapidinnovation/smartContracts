const { Provider } = require("@ethersproject/abstract-provider");
const { expect } = require("chai");
const { utils, providers, getDefaultProvider } = require("ethers");
const { ethers } = require("hardhat");

/**************************************Reserve bond******************************************** */

describe("Reserve Bond Contract", function() {
	let bond;
	let zeroAddress = "0x0000000000000000000000000000000000000000";
	let treasury;
	let ldfBondParking;
	let USDC;
	let native;
	let amount = "4000000000000000000";

	it("Should deploy Bond Contract", async function() {

		const ldfToken = await ethers.getContractFactory("ldftoken");
		native = await ldfToken.deploy();
		console.log("Address of native token",native.address);

		const PToken = await ethers.getContractFactory("ldftoken");
		USDC = await PToken.deploy();
		console.log("Address of principal token", USDC.address);

		const parking = await ethers.getContractFactory("ldfBondParking");
        ldfBondParking = await parking.deploy(native.address, "1", "300000000000000000000000");
        console.log("Address of ldfBondParking contract", ldfBondParking.address);

		const ldfTreasury = await ethers.getContractFactory("ldfTreasury");
        treasury = await ldfTreasury.deploy(native.address, USDC.address, zeroAddress, zeroAddress, ldfBondParking.address, "0");
        console.log("Address of treasury contract", treasury.address);

		const ldfbond = await ethers.getContractFactory("ldfBondDepository");
		bond = await ldfbond.deploy(native.address, USDC.address, treasury.address, zeroAddress);
		console.log("Address of bond contract", utils.getAddress(bond.address));

	});

	describe("Do all the required steps before interacting with bond contract", function() {

		it("Should be able to deposit native token and add treasury address into ldfbondparking contract", async function() {
			const approveAmount = await native.approve(ldfBondParking.address, "175000000000000000000000000");
	
			const depositAmount = await ldfBondParking.deposit("175000000000000000000000000", {
			gasLimit: 100000,
			});
			await depositAmount.wait();
	
			const totalsupply = await ldfBondParking.totalDeposited();

			await ldfBondParking.manage(treasury.address);
	
			expect(await totalsupply).to.equal("175000000000000000000000000");
		});

		it("Should be able to queue and toggle", async function() {
			const queueReserveDepositer = await treasury.queue("0", bond.address);
            await queueReserveDepositer.wait();

            const toggleReserveDepositer = await treasury.toggle("0", bond.address, zeroAddress);
            await toggleReserveDepositer.wait();
		});
	});

	describe("Initailize bond, Deposit reserve and withdraw native", function() {

		it("Should Initialize bond terms and deposit", async function() {
			const [owner, addr1, addr2] = await ethers.getSigners();

			const initializeBondTerms = await bond.initializeBondTerms("300", "1", "160", "50", "100000000000000000000000", "0", {
				gasLimit: 10000000,
			});
			const beforeDeposit = await USDC.balanceOf(owner.address);

			 { 
				let provider = providers.getDefaultProvider();
				let block = await provider.getBlockNumber();
				console.log("block number after", block);
 
				await USDC.approve(bond.address, (amount));

				if(beforeDeposit > amount) {

					const bondDeposit = await bond.deposit(amount, "1203", owner.address, {
						gasLimit: 10000000,
					});
					await bondDeposit.wait();
					console.log("Deposited amount: ", amount);

				} else if(beforeDeposit < amount) {

					const bondDeposit = await bond.deposit(beforeDeposit, "1203", owner.address, {
						gasLimit: 10000000,
					});
					await bondDeposit.wait();
					console.log("Deposited amount: ", beforeDeposit);

				} else {

					console.log("insufficient balance in owner's account")

				}
			}
			
			{ 
				let provider = providers.getDefaultProvider();
				let block = await provider.getBlockNumber();
				console.log("block number after", block);

				await USDC.approve(bond.address, (amount));

				if(beforeDeposit > amount) {

					const bondDeposit = await bond.deposit(amount, "1203", owner.address, {
						gasLimit: 10000000,
					});
					await bondDeposit.wait();
					console.log("Deposited amount: ", amount);

				} else if(beforeDeposit < amount) {

					const bondDeposit = await bond.deposit(beforeDeposit, "1203", owner.address, {
						gasLimit: 10000000,
					});
					await bondDeposit.wait();
					console.log("Deposited amount: ", beforeDeposit);

				} else {

					console.log("insufficient balance in owner's account")

				}
			}
			{ 
				let provider = providers.getDefaultProvider();
				let block = await provider.getBlockNumber();
				console.log("block number after", block);
				
				await USDC.approve(bond.address, (amount));

				if(beforeDeposit > amount) {

					const bondDeposit = await bond.deposit(amount, "1203", owner.address, {
					gasLimit: 10000000,
					});
					await bondDeposit.wait();
					console.log("Deposited amount: ", amount);

				} else if(beforeDeposit < amount) {

					const bondDeposit = await bond.deposit(beforeDeposit, "1203", owner.address, {
						gasLimit: 10000000,
					});
					await bondDeposit.wait();
					console.log("Deposited amount: ", beforeDeposit);

				} else {

					console.log("insufficient balance in owner's account")

				}
			}

			const afterDeposit = await USDC.balanceOf(owner.address);
			console.log("Balance of the owner after deposit", afterDeposit);

			expect(beforeDeposit).to.equal(afterDeposit.add(BigInt(amount*3)));
		});

		it("Should able to with draw the ldf token", async function() {

			let provider = providers.getDefaultProvider();
			let block = await provider.getBlockNumber();
			console.log("block number after", block);

			const [owner, addr1, addr2] = await ethers.getSigners();

			// const info = await bond.bondInfo(owner.address);
			// console.log(info);

			const beforeWithdraw = await native.balanceOf(owner.address);
			console.log("Balance of the owner before withdraw", beforeWithdraw);

			const withdraw = await bond.redeem(owner.address, 0);
			const donewithdraw = await withdraw.wait();
			// console.log(donewithdraw);
			// console.log(donewithdraw.events?.filter((x) => {return x.event == "BondRedeemed"}));

			const afterWithdraw = await native.balanceOf(owner.address);
			console.log("Balance of the owner after withdraw", afterWithdraw);

			console.log("********end redeem********");
		});

		it("Should be able to redeem all the bonds", async function() {

			let provider = providers.getDefaultProvider();
			let block = await provider.getBlockNumber();
			console.log("block number after", block);

			// for(let index = 0; index < 20; index++) {
			// 	await ethers.provider.send('evm_mine');
			// }
			// let block1 = await provider.getBlockNumber();
			// console.log("block number after", block1);

			const [owner, addr1, addr2] = await ethers.getSigners();

			const beforeWithdraw = await native.balanceOf(owner.address);
			console.log("Balance of the owner before withdraw", beforeWithdraw);

			var userbond = await bond.userBonds(owner.address, 0);
			console.log("user bonds in redeemall function", userbond);

			const withdraw = await bond.redeemAll(owner.address);
			await withdraw.wait();

			const afterWithdraw = await native.balanceOf(owner.address);
			console.log("Balance of the owner after withdraw", afterWithdraw);

			console.log("********end redeemAll********");
		});
	});

	// describe("All view Function", function() {

	// 	it("Should be able to check DebtDecay", async function() {
	// 		block = await provider.getBlockNumber();
	// 		console.log("Block number at the time of DebtDecay", block);

	// 		const DebtDecay = await bond.debtDecay();
	// 		console.log("DebtDecay: ", DebtDecay);
	// 	});

	// 	it("Should be able to check currentdebt", async function() {
	// 		const CurrentDebt = await bond.currentDebt();
	// 		console.log("CurrentDebt: ", CurrentDebt);
	// 	});

	// 	it("Should be able to check debtratio", async function() {
	// 		const DebtRatio = await bond.debtRatio();
	// 		console.log("debtRatio", DebtRatio);
	// 	});

	// 	it("Should be able to check bondPrice", async function() {
	// 		const BondPrice = await bond.bondPrice();
	// 		console.log("BondPrice: ", BondPrice);

	// 		expect(await BondPrice).to.equal("160");
	// 	});

	// 	it("Should be able to check maxpayout", async function() {
	// 		const MaxPayout = await bond.maxPayout();
	// 		console.log("maximum payout: ", MaxPayout);
	// 	});

	// 	it("Should be able to check percentVestedFor of depositor", async function() {
	// 		const PercentVestedFor = await bond.percentVestedFor(owner);
	// 		console.log("PercentVestedFor: ", PercentVestedFor);
	// 	});

	// 	it("Should be able to check pendingPayoutFor of depositor", async function() {
	// 		const PendingPayoutFor = await bond.pendingPayoutFor(owner);
	// 		console.log("PendingPayoutFor: ", PendingPayoutFor);
	// 	});
	// });
});