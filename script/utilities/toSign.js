exports.toSign = {
	"0x000000000000000000000000000000000000b4b3": [
		// Working
		{
			id: 1,
			uri: "someUri.json",
			expiration: 1664219311,
			price: 0,
		},
		{
			id: 2,
			uri: "newUri.json",
			expiration: 1664219311,
			price: 0,
		},
		// No uri
		{
			id: 3,
			uri: "",
			expiration: 1664219311,
			price: 0,
		},
		// Expired
		{
			id: 4,
			uri: "expired",
			expiration: 1660219311,
			price: 0,
		},
	],
	"0xdFBC04efe03ED6377751cB1b2c4Abc20a97402cE": [
		{
			id: 42,
			uri: "testing/42.json",
			expiration: 1667060841,
			price: 0,
		},
	],
	"0x1273D47090B70356291a5A57aedcaB7479a9EEb8": [
		{
			id: 42,
			uri: "testing/42.json",
			expiration: 1667060841,
			price: 0,
		},
	],
	"0x0000000000000000000000000000000000000B0b": [
		{
			id: 1,
			uri: "someUri.json",
			expiration: 1664219311,
			price: 0,
		},
	],
};
