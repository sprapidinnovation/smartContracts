async function main() {
  const [owner] = await ethers.getSigners();

  const Instance = await ethers.getContractFactory("NFTScalping");
  const NFTScalping = await Instance.deploy(
    "0x51756B9F0399076ED20c090eF86b053aAE7668f2",
    "0x737AE8F0458c9454732406b75058ED3731B82311"
  );
  console.log("NFTScalping deployed at: \t", NFTScalping.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
