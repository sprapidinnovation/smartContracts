async function main() {
  const [owner] = await ethers.getSigners();

  const Instance = await ethers.getContractFactory(
    "contracts/RadiusStaking.sol:RadiusStaking"
  );
  const RadiusStaking = await Instance.deploy(
    "0x737AE8F0458c9454732406b75058ED3731B82311"
  );
  console.log("RadiusStaking deployed at: \t", RadiusStaking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
