const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFT Scalping Contract", () => {
  let Instance;

  let Radius;
  let ScalperNFT;
  let NFTScalping;

  let owner;
  let user1, user2, user3;
  let addrs;

  beforeEach(async function () {
    [owner, user1, user2, user3, ...addrs] = await ethers.getSigners();

    Instance = await ethers.getContractFactory(
      "contracts/RadiusCoin.sol:RadiusCoin"
    );
    Radius = await Instance.deploy();

    Instance = await ethers.getContractFactory("ScalperNFT");
    ScalperNFT = await Instance.deploy("ScalperNFT", "SCP");

    Instance = await ethers.getContractFactory("NFTScalping");
    NFTScalping = await Instance.deploy(ScalperNFT.address, Radius.address);
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

    it("Should deploy the Scalper NFT successfully", async function () {
      const name = await ScalperNFT.name();
      expect(name).to.be.equal("ScalperNFT");

      const symbol = await ScalperNFT.symbol();
      expect(symbol).to.be.equal("SCP");
    });

    it("Should deploy the NFT Scalping successfully", async function () {
      const totalAllocationLimit = await NFTScalping.totalAllocationLimit();
      expect(totalAllocationLimit).to.be.equal("9900");
    });
  });

  describe("Mint NFTs", function () {
    it("Should fail to mint - (do not have minter role)", async function () {
      await expect(
        NFTScalping.mint("hashofimage", "metadataofimage", 1)
      ).to.be.revertedWith("Caller not NFTScalping contract");
    });

    it("Should fail to mint - (can not mint 0 NFTs)", async function () {
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);
      await expect(
        NFTScalping.mint("hashofimage", "metadataofimage", 0)
      ).to.be.revertedWith("cannot mint 0 NFTs");
    });

    it("Should fail to mint - (image hash already exists)", async function () {
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);
      await NFTScalping.mint("hashofimage", "metadataofimage", 1);
      await expect(
        NFTScalping.mint("hashofimage", "metadataofimage", 1)
      ).to.be.revertedWith("Image already exists");
    });

    it("Should be able to mint", async function () {
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      expect(await ScalperNFT.exists(0)).to.be.equal(true);
    });
  });

  describe("Set Rental Levels", function () {
    it("Should fail to set the rental information - (Not set by the owner)", async function () {
      await expect(
        NFTScalping.connect(user1).setRentalInformation(
          0,
          ethers.utils.parseEther("1"),
          ethers.utils.parseUnits("1", 9),
          +(Date.now() / 1000).toFixed() + 86400,
          1000
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should fail to set the rental information - (Level not in Range)", async function () {
      await expect(
        NFTScalping.setRentalInformation(
          6, // incorrect level
          ethers.utils.parseEther("1"),
          ethers.utils.parseUnits("1", 9),
          +(Date.now() / 1000).toFixed() + 86400,
          1000
        )
      ).to.be.reverted;
    });

    it("Should fail to set the rental information - (Price in AVAX zero)", async function () {
      await expect(
        NFTScalping.setRentalInformation(
          5,
          ethers.utils.parseEther("0"),
          ethers.utils.parseUnits("1", 9),
          +(Date.now() / 1000).toFixed() + 86400,
          1000
        )
      ).to.be.revertedWith(
        "NFTScalping: _priceInAvax must be greater than zero"
      );
    });

    it("Should fail to set the rental information - (Price in Radius zero)", async function () {
      await expect(
        NFTScalping.setRentalInformation(
          5,
          ethers.utils.parseEther("1"),
          ethers.utils.parseUnits("0", 9),
          +(Date.now() / 1000).toFixed() + 86400,
          1000
        )
      ).to.be.revertedWith(
        "NFTScalping: _priceInRadius must be greater than zero"
      );
    });

    it("Should fail to set the rental information - (Duration is zero)", async function () {
      await expect(
        NFTScalping.setRentalInformation(
          5,
          ethers.utils.parseEther("1"),
          ethers.utils.parseUnits("1", 9),
          0,
          1000
        )
      ).to.be.revertedWith("NFTScalping: _duration must be greater than zero");
    });

    it("Should fail to set the rental information - (Scalping percentage zero)", async function () {
      await expect(
        NFTScalping.setRentalInformation(
          5,
          ethers.utils.parseEther("1"),
          ethers.utils.parseUnits("1", 9),
          +(Date.now() / 1000).toFixed() + 86400,
          0
        )
      ).to.be.revertedWith(
        "NFTScalping: _scalpingPercentage must be within range (0 - 10000)"
      );
    });

    it("Should fail to set the rental information - (Scalping percentage out of range)", async function () {
      await expect(
        NFTScalping.setRentalInformation(
          5,
          ethers.utils.parseEther("1"),
          ethers.utils.parseUnits("1", 9),
          +(Date.now() / 1000).toFixed() + 86400,
          10001
        )
      ).to.be.revertedWith(
        "NFTScalping: _scalpingPercentage must be within range (0 - 10000)"
      );
    });
  });

  describe("Rent NFT Test", function () {
    it("Should fail to rent NFT - (NFT does not exist)", async function () {
      await expect(NFTScalping.rentNFT(0, 0, 0)).to.be.revertedWith(
        "NFT does not exist"
      );
    });

    it("Should fail to rent NFT - (rental information not set)", async function () {
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);
      // Mint NFT
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      await expect(NFTScalping.rentNFT(0, 0, 0)).to.be.revertedWith(
        "NFTScalping: rental information not set"
      );
    });

    it("Should fail to rent NFT - (Coin payment insufficient)", async function () {
      block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      // Set rental information
      await NFTScalping.setRentalInformation(
        0,
        ethers.utils.parseEther("1"),
        ethers.utils.parseUnits("1", 9),
        time + 86400 * 7 * 4 * 1,
        1000
      );

      // set the minter role in ScalperNFT
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);

      // Mint the NFT
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      await expect(
        NFTScalping.connect(user1).rentNFT(0, 0, 0)
      ).to.be.revertedWith("NFTScalping: payment insufficient");

      await expect(
        NFTScalping.connect(user1).rentNFT(0, 0, 0, {
          value: ethers.utils.parseEther("0.5"),
        })
      ).to.be.revertedWith("NFTScalping: payment insufficient");
    });

    it("Should fail to rent NFT - (Token payment not approved)", async function () {
      block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      // Set rental information
      await NFTScalping.setRentalInformation(
        0,
        ethers.utils.parseEther("1"),
        ethers.utils.parseUnits("1", 9),
        time + 86400 * 7 * 4 * 1,
        1000
      );

      // set the minter role in ScalperNFT
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);

      // Mint the NFT
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      await expect(
        NFTScalping.connect(user1).rentNFT(0, 0, 1)
      ).to.be.revertedWith("NFTScalping: price amount not approved");

      // Approve insufficient Radius coin
      await Radius.connect(user1).approve(
        NFTScalping.address,
        ethers.utils.parseUnits("0.5", 9)
      );

      await expect(
        NFTScalping.connect(user1).rentNFT(0, 0, 1)
      ).to.be.revertedWith("NFTScalping: price amount not approved");
    });

    it("Should be able to rent NFT - (Using Radius Coin)", async function () {
      block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      // Set rental information
      await NFTScalping.setRentalInformation(
        0,
        ethers.utils.parseEther("1"),
        ethers.utils.parseUnits("1", 9),
        time + 86400 * 7 * 4 * 1,
        1000
      );

      // set the minter role in ScalperNFT
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);

      // Mint the NFT
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      await Radius.transfer(user1.address, ethers.utils.parseUnits("2", 9));

      // Approve Radius coin
      await Radius.connect(user1).approve(
        NFTScalping.address,
        ethers.utils.parseUnits("1", 9)
      );

      // Rent NFT with Radius Token
      await NFTScalping.connect(user1).rentNFT(0, 0, 1);

      // check whether the NFT is assigned to the user
      const tenant = await NFTScalping.getTenant(0);
      expect(tenant).to.be.equal(user1.address);

      // check whether the NFT rent status is true or not
      expect(await NFTScalping.isRentActive(0)).to.be.equal(true);
    });

    it("Should be able to rent NFT - (Using AVAX)", async function () {
      block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      // Set rental information
      await NFTScalping.setRentalInformation(
        0,
        ethers.utils.parseEther("1"),
        ethers.utils.parseUnits("1", 9),
        time + 86400 * 7 * 4 * 1,
        1000
      );

      // set the minter role in ScalperNFT
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);

      // Mint the NFT
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      // Rent NFT with Radius Token
      await NFTScalping.connect(user1).rentNFT(0, 0, 0, {
        value: ethers.utils.parseEther("1"),
      });

      // check whether the NFT is assigned to the user
      const tenant = await NFTScalping.getTenant(0);
      expect(tenant).to.be.equal(user1.address);

      // check whether the NFT rent status is true or not
      expect(await NFTScalping.isRentActive(0)).to.be.equal(true);
    });
  });

  describe("Claim Rewards Test", function () {
    it("Should fail to claim rewards - (NFT is not on rent)", async function () {
      block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      // Set rental information
      await NFTScalping.setRentalInformation(
        0,
        ethers.utils.parseEther("1"),
        ethers.utils.parseUnits("1", 9),
        time + 86400 * 7 * 4 * 1,
        1000
      );

      // set time interval for Rewards
      await NFTScalping.setTimeIntervalForRewards(86400 * 7);

      // set the minter role in ScalperNFT
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);

      // Mint the NFT
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      await Radius.transfer(
        NFTScalping.address,
        ethers.utils.parseUnits("1", 9)
      );

      await expect(
        NFTScalping.connect(user1).transferRewards(0)
      ).to.be.revertedWith("NFTScalping: NFT not on rent");
    });

    it("Should fail to claim rewards - (Claiming before scalp time)", async function () {
      block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      // Set rental information
      await NFTScalping.setRentalInformation(
        0,
        ethers.utils.parseEther("1"),
        ethers.utils.parseUnits("1", 9),
        time + 86400 * 7 * 4 * 1,
        1000
      );

      // set time interval for Rewards
      await NFTScalping.setTimeIntervalForRewards(86400 * 7);

      // set the minter role in ScalperNFT
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);

      // Mint the NFT
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      // Rent NFT with Radius Token
      await NFTScalping.connect(user1).rentNFT(0, 0, 0, {
        value: ethers.utils.parseEther("1"),
      });

      await Radius.transfer(
        NFTScalping.address,
        ethers.utils.parseUnits("1", 9)
      );

      await expect(
        NFTScalping.connect(user1).transferRewards(0)
      ).to.be.revertedWith(
        "NFTScalping: can not transfer rewards before next scalp time"
      );
    });

    it("Should be able to claim rewards", async function () {
      block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      // Set rental information
      await NFTScalping.setRentalInformation(
        0,
        ethers.utils.parseEther("1"),
        ethers.utils.parseUnits("1", 9),
        time + 86400 * 7 * 4 * 1,
        1000
      );

      // set time interval for Rewards
      await NFTScalping.setTimeIntervalForRewards(86400 * 7);

      // set the minter role in ScalperNFT
      await ScalperNFT.setNFTScalpingAddress(NFTScalping.address);

      // Mint the NFT
      await NFTScalping.mint("hashofimage", "metadataofimage", 10);

      // Rent NFT with Radius Token
      await NFTScalping.connect(user1).rentNFT(0, 0, 0, {
        value: ethers.utils.parseEther("1"),
      });

      await Radius.transfer(
        NFTScalping.address,
        ethers.utils.parseUnits("1", 9)
      );

      block = await ethers.provider.getBlock("latest");
      time = block.timestamp;

      await network.provider.send("evm_increaseTime", [time + 86400 * 7]);
      await network.provider.send("evm_mine");

      await NFTScalping.connect(user1).transferRewards(0);
    });
  });
});
