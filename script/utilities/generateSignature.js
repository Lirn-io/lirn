const fs = require("fs");
const hre = require("hardhat");
const { ethers, network } = require("hardhat");
const { toSign } = require("./toSign");

const zip = (rows) => rows[0].map((_, c) => rows.map((row) => row[c]));
const objectMap = (obj, fn) =>
	Object.fromEntries(Object.entries(obj).map(([k, v], i) => [k, fn(k, v, i)]));
const promiseAllObj = async (obj) =>
	Object.fromEntries(
		zip([Object.keys(obj), await Promise.all(Object.values(obj))])
	);

const sign = async (
	signer,
	contractAddress,
	id,
	uri,
	expiration,
	price,
	userAccount
) => {
	userAccount = ethers.utils.getAddress(userAccount);
	contractAddress = ethers.utils.getAddress(contractAddress);

	// @note ADD price to signed message
	return await signer.signMessage(
		ethers.utils.arrayify(
			ethers.utils.keccak256(
				ethers.utils.defaultAbiCoder.encode(
					["address", "uint256", "string", "uint256", "uint256", "address"],
					[contractAddress, id, uri, expiration, price, userAccount]
				)
			)
		)
	);
};

async function main() {
	const [owner, addr1] = await ethers.getSigners();

	//const contractAddress = "0xce71065d4017f316ec606fe4422e11eb2c47c246"; // only via forge tests
	const contractAddress = "0x0af27bf79F8e27c06F0570F60b34B6D4B0Fea19A"; // deployed on goerli

	console.log("signer address:", addr1.address);

	let sig = {};

	for (const [key, value] of Object.entries(toSign)) {
		let arr = await Promise.all(
			value.map(
				async (obj) =>
					await sign(
						// If on goerli, comment out owner and replace with addr1, if local tests then do the opposite
						//addr1, // GOERLI
						owner, // FORGE TESTS
						contractAddress,
						obj.id,
						obj.uri,
						obj.expiration,
						obj.price,
						key
					)
			)
		);
		let obj = {};
		obj[key] = arr;

		Object.assign(sig, obj);
	}

	console.log("writing to file");
	fs.writeFileSync(
		"signatures.js",
		"export const signatures = " + JSON.stringify(sig, null, 2),
		console.log
	);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
