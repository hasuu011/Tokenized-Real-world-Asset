const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying TokenizedRWA contract to Core Testnet 2...");

  // Get the contract factory
  const TokenizedRWA = await ethers.getContractFactory("TokenizedRWA");

  // Define the constructor parameters
  const tokenName = "Tokenized Real Estate Fund";
  const tokenSymbol = "TREF";
  const assetType = "Commercial Real Estate";
  const assetIdentifier = "Property Portfolio #12345";
  const assetLocation = "123 Main Street, Metropolis";
  const totalValuation = ethers.parseEther("5000000"); // $5 million in wei format
  const maxInvestors = 100;

  // Deploy the contract
  const tokenizedRWA = await TokenizedRWA.deploy(
    tokenName,
    tokenSymbol,
    assetType,
    assetIdentifier,
    assetLocation,
    totalValuation,
    maxInvestors
  );

  // Wait for deployment to complete
  await tokenizedRWA.waitForDeployment();

  // Get the contract address
  const contractAddress = await tokenizedRWA.getAddress();
  
  console.log(`TokenizedRWA deployed to: ${contractAddress}`);
  console.log("Contract parameters:");
  console.log(`- Token Name: ${tokenName}`);
  console.log(`- Token Symbol: ${tokenSymbol}`);
  console.log(`- Asset Type: ${assetType}`);
  console.log(`- Asset Identifier: ${assetIdentifier}`);
  console.log(`- Asset Location: ${assetLocation}`);
  console.log(`- Total Valuation: $${ethers.formatEther(totalValuation)}`);
  console.log(`- Max Investors: ${maxInvestors}`);
  
  console.log("\nVerify contract on explorer with:");
  console.log(`npx hardhat verify --network coreTestnet2 ${contractAddress} "${tokenName}" "${tokenSymbol}" "${assetType}" "${assetIdentifier}" "${assetLocation}" ${totalValuation} ${maxInvestors}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
