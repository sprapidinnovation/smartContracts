const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Radius Token Contract", () => {
  let Instance;

  let Radius;

  let owner;
  let user1, user2, user3;
  let reservePool, liquidityPool;
  let addrs;

  beforeEach(async function () {
    [owner, user1, user2, user3, reservePool, liquidityPool, ...addrs] =
      await ethers.getSigners();

    Instance = await ethers.getContractFactory(
      "contracts/RadiusCoin.sol:RadiusCoin"
    );
    Radius = await Instance.deploy();

    // set the reserve pool address
    await Radius.setReservePool(reservePool.address);

    // set the liquidity pool address
    await Radius.setLiquidityPoolAddress(liquidityPool.address, true);

    // set tax fee
    await Radius.setReflectionFee(100);

    // distribute some radius to users for testing
    await Radius.transfer(user1.address, ethers.utils.parseUnits("1", 9));
    await Radius.transfer(user2.address, ethers.utils.parseUnits("1", 9));
    await Radius.transfer(user3.address, ethers.utils.parseUnits("1", 9));
  });

  describe("Deployment", function () {
    it("Should deploy the Radius Token Successfully", async function () {
      const name = await Radius.name();
      expect(name).to.be.equal("Radius Coin");

      const symbol = await Radius.symbol();
      expect(symbol).to.be.equal("RADIUS");

      const decimals = await Radius.decimals();
      expect(decimals).to.be.equal(9);
    });
  });

  describe("Transfer Test", function () {
    it("Should fail to transfer - (sending to zero address)", async function () {
      await expect(
        Radius.connect(user1).transfer(
          ethers.constants.AddressZero,
          ethers.utils.parseUnits("0.5", 9)
        )
      ).to.be.revertedWith("ERC20: transfer to the zero address");
    });

    it("Should fail to transfer - (zero amount transfer)", async function () {
      let block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      await expect(
        Radius.connect(user1).transfer(
          user2.address,
          ethers.utils.parseUnits("0", 9)
        )
      ).to.be.revertedWith("Transfer amount must be greater than zero");
    });

    it("Should fail to transfer - (transfer halt active)", async function () {
      await Radius.setHaltPeriods([10, 15, 20]);

      await Radius.executePriceDeclineHalt(
        ethers.utils.parseEther("100"),
        ethers.utils.parseEther("84")
      );

      await Radius.connect(user1).transfer(
        user2.address,
        ethers.utils.parseUnits("1", 9)
      );

      const currentHaltLevel = await Radius.currentHaltLevel();
      console.log(
        "🚀 ~ file: radiusCoin.test.js ~ line 77 ~ currentHaltLevel",
        currentHaltLevel
      );
      const currentHaltPeriod = await Radius.currentHaltPeriod();
      console.log(
        "🚀 ~ file: radiusCoin.test.js ~ line 79 ~ currentHaltPeriod",
        currentHaltPeriod - time
      );
    });

    it("Test mint", async function () {
      await Radius.connect(reservePool).mint(ethers.utils.parseUnits("10", 9));
    });
  });
});
