// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "foundry-upgrades/ProxyTester.sol";
import "../src/SoulboundUUPS.sol";
import "../src/SoulboundUUPSv2.sol";

contract ContractTest is Test {
    ProxyTester proxy;
    SoulboundUUPS soulbound;
    SoulboundUUPSv2 soulboundV2;

    address proxyAddress;
    address admin;

    address alice = address(0xb4b3);
    address bob = address(0xB0b);
    address tester = address(this);

    function setUp() public {
        proxy = new ProxyTester();
        soulbound = new SoulboundUUPS();
        soulboundV2 = new SoulboundUUPSv2();

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(tester, "Tester");
        vm.label(address(soulbound), "Soulbound");

        proxy.setType("uups");
        proxyAddress = proxy.deploy(address(soulbound), alice);
    }

    function testDeployUUPS() public {
        address proxyAddressTest;
        proxy.setType("uups");
        proxyAddressTest = proxy.deploy(address(soulbound), alice);
        assertEq(proxyAddressTest, proxy.proxyAddress());
        assertEq(proxyAddressTest, address(proxy.uups()));
        bytes32 implSlot = bytes32(
            uint256(keccak256("eip1967.proxy.implementation")) - 1
        );
        bytes32 proxySlot = vm.load(proxyAddressTest, implSlot);
        address addr;
        assembly {
            mstore(0, proxySlot)
            addr := mload(0)
        }
        assertEq(address(soulbound), addr);
    }

    // TODO Test initialize, test called only once, test authorization, test upgrade
    // TODO Test uninitialized proxy vuln.

    function testInitialize() public {
        vm.prank(bob);
        (bool success, bytes memory data) = proxyAddress.call(
            abi.encodeWithSignature(
                "initialize(address,address,string)",
                bob,
                bob,
                "test"
            )
        );
        assertEq(success, true);

        (success, data) = proxyAddress.call(
            abi.encodeWithSignature("defaultURI()")
        );
        string memory uri = abi.decode(data, (string));
        assertEq(uri, "test");

        (success, data) = proxyAddress.call(abi.encodeWithSignature("owner()"));
        address owner = abi.decode(data, (address));
        assertEq(owner, bob);
    }

    function test_CannotInitializeTwice() public {
        vm.prank(bob);
        (bool success, bytes memory data) = proxyAddress.call(
            abi.encodeWithSignature(
                "initialize(address,address,string)",
                bob,
                bob,
                "test"
            )
        );
        assertEq(success, true);

        (success, data) = proxyAddress.call(
            abi.encodeWithSignature(
                "initialize(address,string)",
                alice,
                "test2"
            )
        );
        assertEq(success, false);
    }

    function test_Upgrade() public {
        // V1
        vm.prank(bob);
        (bool success, bytes memory data) = proxyAddress.call(
            abi.encodeWithSignature(
                "initialize(address,address,string)",
                bob,
                bob,
                "test"
            )
        );
        assertEq(success, true);

        (success, data) = proxyAddress.call(
            abi.encodeWithSignature("CONTRACT_NAME()")
        );
        assertEq(abi.decode(data, (string)), soulbound.CONTRACT_NAME());

        (success, data) = proxyAddress.call(
            abi.encodeWithSignature("VERSION()")
        );
        assertEq(abi.decode(data, (string)), soulbound.VERSION());

        // Upgrade
        proxy.upgrade(address(soulboundV2), alice, address(0));

        vm.prank(bob);

        (success, data) = proxyAddress.call(
            abi.encodeWithSignature("CONTRACT_NAME()")
        );
        assertEq(abi.decode(data, (string)), soulboundV2.CONTRACT_NAME());

        (success, data) = proxyAddress.call(
            abi.encodeWithSignature("VERSION()")
        );
        assertEq(abi.decode(data, (string)), soulboundV2.VERSION());

        (success, data) = proxyAddress.call(abi.encodeWithSignature("owner()"));
        address owner = abi.decode(data, (address));
        assertEq(owner, bob);
    }
}
