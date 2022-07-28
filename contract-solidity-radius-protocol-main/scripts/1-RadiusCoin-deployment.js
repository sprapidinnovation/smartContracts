async function main() {
  const [owner] = await ethers.getSigners();

  const Instance = await ethers.getContractFactory(
    "contracts/RadiusCoin.sol:RadiusCoin"
  );
  const RadiusCoin = await Instance.deploy();
  console.log("RadiusCoin deployed at: \t", RadiusCoin.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
