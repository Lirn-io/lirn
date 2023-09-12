const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const { BigNumber, utils } = require("ethers");
const {
	centerTime,
	getBlockTimestamp,
	jumpToTime,
	advanceTime,
} = require("../script/utilities/utility.js");

const BN = BigNumber.from;
var time = centerTime();

const signWhitelist = async (
	signer,
	contractAddress,
	userAccount,
	period,
	data
) => {
	userAccount = ethers.utils.getAddress(userAccount);
	contractAddress = ethers.utils.getAddress(contractAddress);

	return await signer.signMessage(
		ethers.utils.arrayify(
			ethers.utils.keccak256(
				ethers.utils.defaultAbiCoder.encode(
					["address", "uint256", "uint256", "address"],
					[contractAddress, period, data, userAccount]
				)
			)
		)
	);
};

describe("Deploy", function () {
	let proxy, soulbound, owner, addr1, addr2;

	beforeEach(async function () {
		[owner, addr1, addr2] = await ethers.getSigners();

		const Soulbound = await ethers.getContractFactory("SoulboundUUPS");
		soulbound = await upgrades.deployProxy(
			Soulbound,
			[addr1.address, owner.address, "test/"],
			{ initializer: "initialize" },
			{ kind: "uups" }
		);
	});

	it("Properly initialized owner, signer, and defaultURI", async function () {
		expect(await soulbound.owner()).to.equal(addr1.address);
		expect(await soulbound._signerAddress()).to.equal(owner.address);
		expect(await soulbound.defaultURI()).to.equal("test/");
	});
});
