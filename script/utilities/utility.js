const { BigNumber } = require("ethers");
const BN = BigNumber.from;

exports.BN = BigNumber.from;

exports.zip = (rows) => rows[0].map((_, c) => rows.map((row) => row[c]));

exports.objectMap = (obj, fn) =>
	Object.fromEntries(Object.entries(obj).map(([k, v], i) => [k, fn(k, v, i)]));

exports.promiseAllObj = async (obj) =>
	Object.fromEntries(
		zip([Object.keys(obj), await Promise.all(Object.values(obj))])
	);

exports.BNArray = (array) => array.map((i) => BN(i));

exports.filterFirstEventArgs = (receipt, event) =>
	receipt.events.filter((logs) => logs.event == event)[0].args;

exports.shuffleArray = (array) => {
	for (let i = array.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		[array[i], array[j]] = [array[j], array[i]];
	}
};

exports.randomElement = (array) =>
	array[Math.floor(Math.random() * array.length)];

exports.centerTime = (time) => {
	const now = parseInt(time || new Date().getTime() / 1000);

	const delta1s = 1;
	const delta1m = 1 * 60;
	const delta1h = 1 * 60 * 60;
	const delta1d = 24 * 60 * 60;

	var times = { now: BN(now) };

	for (let i = 0; i < 60; i++) {
		times[`delta${i}s`] = BN(i * delta1s);
		times[`delta${i}m`] = BN(i * delta1m);
		times[`delta${i}h`] = BN(i * delta1h);
		times[`delta${i}d`] = BN(i * delta1d);
		times[`delta${i}y`] = BN(i * 365 * delta1d);
		times[`future${i}s`] = BN(now + i * delta1s);
		times[`future${i}m`] = BN(now + i * delta1m);
		times[`future${i}h`] = BN(now + i * delta1h);
		times[`future${i}d`] = BN(now + i * delta1d);
		times[`future${i}y`] = BN(now + i * 365 * delta1d);
	}

	times.future = (t) => {
		return times.now.add(t);
	};

	return times;
};

exports.jumpToTime = async (t) => {
	await network.provider.send("evm_mine", [t.toNumber()]);
	return this.centerTime(t);
};

exports.advanceTime = async (t) => {
	let time = this.centerTime(await this.getBlockTimestamp());
	return await this.jumpToTime(time.future(t));
};

exports.getBlockTimestamp = async () => {
	let blocknum = await network.provider.request({ method: "eth_blockNumber" });
	let block = await network.provider.request({
		method: "eth_getBlockByNumber",
		params: [blocknum, true],
	});
	return BN(block.timestamp).toString();
};

exports.signWhitelist = async (signer, contractAddress, userAccount, data) => {
	return await signer.signMessage(
		ethers.utils.arrayify(
			ethers.utils.keccak256(
				ethers.utils.defaultAbiCoder.encode(
					["address", "uint256", "address"],
					[contractAddress, data, userAccount]
				)
			)
		)
	);
};

exports.verify = async function (address, constructorArguments) {
	console.log(
		"verifying",
		address,
		(constructorArguments &&
			`with arguments ${constructorArguments.join(", ")}`) ||
			""
	);
	await hre.run("verify:verify", {
		address: address,
		constructorArguments: constructorArguments,
	});
};
