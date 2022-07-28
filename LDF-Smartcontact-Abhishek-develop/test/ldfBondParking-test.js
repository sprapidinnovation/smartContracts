const { expect } = require("chai");

describe("ldfBondParking contract", function() {
    let native;
    let owner = "0x555c74B09A29e083EA6F661c2dD78617d8Fd906E";
    let ldfBondParking;

    it("Should be able to deploy ldfBondParking Contract", async function() {
        const ldfToken = await ethers.getContractFactory("ldftoken");
		native = await ldfToken.deploy();
        // await native.deployed();
		console.log("Address of native token",native.address);  

        const bondParking = await ethers.getContractFactory("ldfBondParking");
        ldfBondParking = await bondParking.deploy(native.address, "1", "3000000000000000000000");
        console.log("Address of ldfBondParking contract", ldfBondParking.address);
    });

    it("Should be able to deposit tokens", async function() {
        const beforeBalance = await native.balanceOf(owner);
        console.log("Owner balance before deposit", beforeBalance);

        await native.approve(ldfBondParking.address, "175000000000000000000000000");

        const deposit = await ldfBondParking.deposit("175000000000000000000000000", {
            gasLimit: 1000000,
        });
        await deposit.wait();

        const afterBalance = await native.balanceOf(owner);
        console.log("Owner balance after deposit", afterBalance);

        expect(await beforeBalance).to.equal(afterBalance.add("175000000000000000000000000"));
    });

    it("Should be able to add treasury address through manage", async function() {
        await ldfBondParking.manage(owner); 
    });

    it("Should be able to transfer native tokens", async function() {
        const balanceBefore = await native.balanceOf(owner);
        console.log("Balance of user1 before transfer", balanceBefore);

        const transfer= await ldfBondParking.transfer(owner, "100000000000000000000", {
            gasLimit: 1000000,
        });
        await transfer.wait();

        const balanceAfter = await native.balanceOf(owner);
        console.log("Balance of user1 after transfer", balanceAfter);

        expect(await balanceBefore).to.equal(balanceAfter.sub("100000000000000000000"));
    });
});