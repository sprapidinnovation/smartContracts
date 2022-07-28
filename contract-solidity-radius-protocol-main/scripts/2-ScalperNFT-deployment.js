async function main() {
  const [owner] = await ethers.getSigners();

  const Instance = await ethers.getContractFactory("ScalperNFT");
  const ScalperNFT = await Instance.deploy("ScalperNFT", "SCP");
  console.log("ScalperNFT deployed at: \t", ScalperNFT.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
