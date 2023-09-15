// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "foundry-upgrades/ProxyTester.sol";
import "../src/SoulboundUUPS.sol";

// TODO: Test pause and unpaused, test migration when allowed

contract ContractTest is Test {
    using stdStorage for StdStorage;

    SoulboundUUPS soulbound;

    address alice = address(0xb4b3);
    address bob = address(0xB0b);
    address tester = address(this);

    address[] mintTo;
    uint256[] ids;
    uint256[] amounts;

    function setUp() public {
        soulbound = new SoulboundUUPS();
        console.log(address(soulbound));
        console.log(alice);
        console.log(bob);

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(tester, "Tester");
        vm.label(address(soulbound), "Soulbound");

        vm.startPrank(bob);
        soulbound.setSigner(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        soulbound.setDefaultURI("test/");
        vm.stopPrank();

        ids.push(1);
        ids.push(2);
        amounts.push(1);
        amounts.push(1);
    }

    function test_Initialized() public {
        assertEq(soulbound.defaultURI(), "test/");
    }

    function test_adminCanMint() public {
        vm.prank(bob);
        soulbound.mint(alice, 1, "canMint/1.json");

        assertEq(soulbound.uri(1), "canMint/1.json");
        assertEq(soulbound.balanceOf(alice, 1), 1);
    }

    function test_adminCanBatchMint() public {
        mintTo.push(alice);
        mintTo.push(bob);

        vm.prank(bob);
        soulbound.batchMint(mintTo, 2, "URI");

        assertEq(soulbound.uri(2), "URI");
        assertEq(soulbound.balanceOf(alice, 2), 1);
        assertEq(soulbound.balanceOf(bob, 2), 1);
    }

    function test_adminCanBurn() public {
        vm.startPrank(bob);
        soulbound.mint(alice, 1, "canMint/1.json");
        assertEq(soulbound.balanceOf(alice, 1), 1);

        soulbound.burn(alice, 1);
        assertEq(soulbound.balanceOf(alice, 1), 0);
    }

    function test_adminCanBatchBurn() public {
        vm.startPrank(bob);
        soulbound.mint(alice, 1, "TEST");
        soulbound.mint(alice, 2, "TEST");
        assertEq(soulbound.balanceOf(alice, 1), 1);
        assertEq(soulbound.balanceOf(alice, 2), 1);

        soulbound.batchBurn(alice, amounts, ids);
        assertEq(soulbound.balanceOf(alice, 1), 0);
        assertEq(soulbound.balanceOf(alice, 2), 0);
        vm.stopPrank();
    }

    function test_adminCanSetCustomURI() public {
        vm.startPrank(bob);
        soulbound.mint(alice, 1, "TEST");

        assertEq(soulbound.uri(1), "TEST");

        soulbound.setCustomURI(1, "CUSTOM");
        assertEq(soulbound.uri(1), "CUSTOM");
        vm.stopPrank();
    }

    function test_adminCanSetDefaultURI() public {
        vm.startPrank(bob);
        soulbound.mint(alice, 1, "");
        assertEq(soulbound.uri(1), "test/1.json");
        vm.stopPrank();
    }

    function test_adminCanSetSigner() public {
        vm.startPrank(bob);
        soulbound.setSigner(alice);
        assertEq(soulbound._signerAddress(), alice);
    }

    function test_revertAuthorizedFunctions() public {
        vm.startPrank(bob);
        soulbound.mint(bob, 1, "test");
        soulbound.mint(bob, 2, "test");
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        soulbound.mint(alice, 1, "test");

        vm.expectRevert("Ownable: caller is not the owner");
        soulbound.batchMint(mintTo, 3, "URI");

        vm.expectRevert("Ownable: caller is not the owner");
        soulbound.burn(bob, 1);

        vm.expectRevert("Ownable: caller is not the owner");
        soulbound.batchBurn(bob, amounts, ids);

        vm.expectRevert("Ownable: caller is not the owner");
        soulbound.setCustomURI(1, "CUSTOM");

        vm.expectRevert("Ownable: caller is not the owner");
        soulbound.setDefaultURI("DEFAULT");

        vm.expectRevert("Ownable: caller is not the owner");
        soulbound.setSigner(alice);

        vm.stopPrank();
    }

    function test_userCanClaimWithSignature() public {
        vm.startPrank(alice);
        //  id: 1,
        //	uri: "someUri.json",
        //	expiration: 1664219311,
        bytes
            memory sig = hex"fb49bc7144472049d2cddca95d40b4c10a4260a357bc93b109470db6625b68e80784c4f35718eef3131f0233bb8ea0ffb15be7cb899744c178e56683e5edf65e1c";

        soulbound.claim(sig, 1, "someUri.json", 1664219311);
        assertEq(soulbound.balanceOf(alice, 1), 1);
        assertEq(soulbound.uri(1), "someUri.json");
        vm.stopPrank();
    }

    function test_multipleUsersCanClaimSameId() public {
        bytes
            memory aliceSig = hex"fb49bc7144472049d2cddca95d40b4c10a4260a357bc93b109470db6625b68e80784c4f35718eef3131f0233bb8ea0ffb15be7cb899744c178e56683e5edf65e1c";
        bytes
            memory bobSig = hex"ba915f3593d66e34acff27011547fe8d964c95cedcddffc945e295307aa9d9fb1877ebf63fd7bb8bbc2169eb0cd3a866820e72af1c00b1367bb1dda7e81225111c";

        vm.prank(alice);
        soulbound.claim(aliceSig, 1, "someUri.json", 1664219311);

        vm.prank(bob);
        soulbound.claim(bobSig, 1, "someUri.json", 1664219311);

        assertEq(soulbound.balanceOf(alice, 1), 1);
        assertEq(soulbound.balanceOf(bob, 1), 1);
        assertEq(soulbound.uri(1), "someUri.json");
    }

    function test_ClaimingWithNoUriSetsUriToDefault() public {
        /* 
            id: 3,
			uri: "",
			expiration: 1664219311,
         */
        bytes
            memory sig = hex"7c2c041bc678ec9479c28bf5489aadfea2a24749e91cba439d4484345d18fac319950f3126486b8e317bb1bf320b61a39f597306acca4bd7ed9b344a3d33ca3f1c";
        vm.prank(alice);
        soulbound.claim(sig, 3, "", 1664219311);
        assertEq(soulbound.balanceOf(alice, 3), 1);
        assertEq(soulbound.uri(3), "test/3.json");
    }

    function test_CannotClaimIfExpired() public {
        /* 
            id: 4,
			uri: "expired",
			expiration: 1660219311,
         */
        bytes
            memory sig = hex"66605ccc0739397774fc1546f7e00f6960afda78aca0577a6f2649a2c9a4ff3a234d976b4b481fbcdc8a030e0078787d786a9f4be650b9f6fc45716ff112baba1b";
        vm.warp(1660219311);
        vm.prank(alice);

        vm.expectRevert("Signature expired");
        soulbound.claim(sig, 4, "expired", 1660219311);
    }

    // TODO Test that the URI doesn't change if already set

    function test_CannotClaimIfAlreadyClaimed() public {
        vm.startPrank(alice);
        //  id: 1,
        //	uri: "someUri.json",
        //	expiration: 1664219311,
        bytes
            memory sig = hex"fb49bc7144472049d2cddca95d40b4c10a4260a357bc93b109470db6625b68e80784c4f35718eef3131f0233bb8ea0ffb15be7cb899744c178e56683e5edf65e1c";

        soulbound.claim(sig, 1, "someUri.json", 1664219311);
        assertEq(soulbound.balanceOf(alice, 1), 1);
        assertEq(soulbound.uri(1), "someUri.json");

        vm.expectRevert("Already claimed");
        soulbound.claim(sig, 1, "someUri.json", 1664219311);
        vm.stopPrank();
    }

    function test_CannotClaimWithWrongSig() public {
        bytes
            memory sig = hex"ba915f3593d66e34acff27011547fe8d964c95cedcddffc945e295307aa9d9fb1877ebf63fd7bb8bbc2169eb0cd3a866820e72af1c00b1367bb1dda7e81225111c";
        vm.prank(alice);
        vm.expectRevert("INCORRECT_SIGNATURE");
        soulbound.claim(sig, 1, "someUri.json", 1664219311);
    }
}
