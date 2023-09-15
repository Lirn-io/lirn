const hre = require("hardhat");

async function main() {
	const [owner, addr1, addr2] = await ethers.getSigners();
	let newOwner, newSigner, defaultURI;
	newOwner = owner.address;
	newSigner = addr1.address;
	defaultURI = "test/";

	const Soulbound = await ethers.getContractFactory("SoulboundUUPS");
	soulbound = await upgrades.deployProxy(
		Soulbound,
		[newOwner, newSigner, defaultURI],
		{ initializer: "initialize" }
	);
	await soulbound.deployed();

	console.log("Soulbound deployed to:", soulbound.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
