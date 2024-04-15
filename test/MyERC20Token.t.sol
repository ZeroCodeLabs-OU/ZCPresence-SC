// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyERC20Token.sol"; // Ensure the path to your contract is correct

contract MyERC20TokenTest is Test {
    MyERC20Token tokenWithLimitedSupply;
    MyERC20Token tokenWithUnlimitedSupply;
    address deployer;
    address user1 = address(0x1);
    address user2 = address(0x2);
    uint256 cap = 1000000 * 1e18;

    function setUp() public {
        deployer = address(this);

        // Instance with limited supply
        tokenWithLimitedSupply = new MyERC20Token(
            "LimitedToken", 
            "LMT", 
            deployer,
            deployer,
            deployer,
            deployer,
            cap, 
            false
        );

        // Instance with unlimited supply
        tokenWithUnlimitedSupply = new MyERC20Token(
            "UnlimitedToken", 
            "ULT", 
            deployer,
            deployer,
            deployer,
            deployer,
            0, 
            true
        );
    }   

    function testInitialBalanceLimited() public view {
        assertEq(tokenWithLimitedSupply.totalSupply(), 0, "Initial supply should be 0 for limited token");
    }

    function testInitialBalanceUnlimited() public view {
        assertEq(tokenWithUnlimitedSupply.totalSupply(), 0, "Initial supply should be 0 for unlimited token");
    }

    function testMintFunctionLimited() public {
        uint256 mintAmount = 500 * 1e18; // Amount below cap
        tokenWithLimitedSupply.mint(user1, mintAmount);
        assertEq(tokenWithLimitedSupply.balanceOf(user1), mintAmount, "Minting did not assign the correct balance for limited token");
    }

    function testMintFunctionUnlimited() public {
        uint256 mintAmount = cap + 500 * 1e18; // Amount exceeding the cap
        tokenWithUnlimitedSupply.mint(user1, mintAmount);
        assertEq(tokenWithUnlimitedSupply.balanceOf(user1), mintAmount, "Minting did not assign the correct balance for unlimited token");
    }

    function testFailUnauthorizedMintLimited() public {
        vm.prank(user1); // Simulate a call from user1
        tokenWithLimitedSupply.mint(user2, 100 * 1e18); // Should fail
    }

    function testPauseAndUnpauseLimited() public {
        tokenWithLimitedSupply.pause();
        vm.expectRevert();
        tokenWithLimitedSupply.transfer(user1, 10);
        
        tokenWithLimitedSupply.unpause();
        tokenWithLimitedSupply.mint(deployer, 10); // Assuming deployer has MINTER_ROLE
        tokenWithLimitedSupply.transfer(user1, 10); // Should succeed after unpausing
    }

    function testCapEnforcementLimited() public {
        uint256 excessAmount = cap + 1e18; // Amount that exceeds the cap by 1
        vm.prank(deployer);
        vm.expectRevert(bytes("MyToken: cap exceeded"));
        tokenWithLimitedSupply.mint(deployer, excessAmount); // This should fail
    }

    function testRoleManagement() public {
        // Ensure deployer has default admin role
        assertTrue(tokenWithLimitedSupply.hasRole(tokenWithLimitedSupply.DEFAULT_ADMIN_ROLE(), deployer));
        
        // Test role assignment
        tokenWithLimitedSupply.grantRole(tokenWithLimitedSupply.MINTER_ROLE(), user1);
        assertTrue(tokenWithLimitedSupply.hasRole(tokenWithLimitedSupply.MINTER_ROLE(), user1));

        // Test role revocation
        tokenWithLimitedSupply.revokeRole(tokenWithLimitedSupply.MINTER_ROLE(), user1);
        assertFalse(tokenWithLimitedSupply.hasRole(tokenWithLimitedSupply.MINTER_ROLE(), user1));
    }

    // Test ERC20 Standard Compliance
    function testERC20Compliance() public {
        uint256 mintAmount = 100 * 1e18;
        // Correctly mint tokens to user1 for testing
        tokenWithLimitedSupply.mint(user1, mintAmount); // Ensure user1 has tokens

        // Simulate user1 attempting to transfer tokens to user2
        vm.prank(user1);
        tokenWithLimitedSupply.transfer(user2, 50 * 1e18);

        assertEq(tokenWithLimitedSupply.balanceOf(user1), 50 * 1e18, "user1 balance should be reduced by 50 tokens");
        assertEq(tokenWithLimitedSupply.balanceOf(user2), 50 * 1e18, "user2 should receive 50 tokens");
    }


// Test burning tokens
    function testBurningTokens() public {
        uint256 mintAmount = 100 * 1e18;
        tokenWithLimitedSupply.mint(deployer, mintAmount); // Mint some tokens for testing

        // Burn some tokens and check total supply
        uint256 burnAmount = 50 * 1e18;
        tokenWithLimitedSupply.burn(burnAmount);
        assertEq(tokenWithLimitedSupply.totalSupply(), mintAmount - burnAmount);
    }

    // Test pausable transfers
    function testPausableTransfers() public {
        uint256 mintAmount = 100 * 1e18;
        // Mint tokens to user1, who will perform the transfer
        tokenWithLimitedSupply.mint(user1, mintAmount);

        // Ensure user1 can transfer tokens normally
        vm.prank(user1);
        tokenWithLimitedSupply.transfer(user2, 50 * 1e18);
        assertEq(tokenWithLimitedSupply.balanceOf(user2), 50 * 1e18, "user2 should have 50 tokens");

        // Test pausing and ensure transfer fails
        tokenWithLimitedSupply.pause();
        vm.prank(user1); // Ensure transfer attempt is from user1
        vm.expectRevert();
        tokenWithLimitedSupply.transfer(user2, 50 * 1e18);
    }
    function testApproveAndTransferFrom() public {
        uint256 mintAmount = 200 * 1e18;
        tokenWithLimitedSupply.mint(user1, mintAmount); // Mint tokens to user1 for testing
        
        // Approve user2 to spend tokens on behalf of user1
        vm.prank(user1); // As user1, approve user2
        tokenWithLimitedSupply.approve(user2, mintAmount);

        // Check allowance
        uint256 allowance = tokenWithLimitedSupply.allowance(user1, user2);
        assertEq(allowance, mintAmount, "Allowance should be set to mintAmount");

        // Transfer from user1 to user2 by user2 using transferFrom
        vm.prank(user2); // As user2, transfer from user1 to user2
        tokenWithLimitedSupply.transferFrom(user1, user2, mintAmount);

        // Check final balances
        assertEq(tokenWithLimitedSupply.balanceOf(user1), 0, "User1 balance should be 0 after transferFrom");
        assertEq(tokenWithLimitedSupply.balanceOf(user2), mintAmount, "User2 balance should be mintAmount after transferFrom");
    }
    function testAirdropFunctionality() public {
        // Assume the setup has already granted the AIRDROPPER_ROLE to deployer.

        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18; // 100 tokens
        amounts[1] = 200e18; // 200 tokens
        uint256 totalAirdroppedAmount = amounts[0] + amounts[1];


        // Execute the airdrop
        tokenWithLimitedSupply.airdrop(recipients, amounts);

        // Verify the balances of the recipients and the total supply
        assertEq(tokenWithLimitedSupply.balanceOf(user1), amounts[0], "Incorrect user1 balance after airdrop");
        assertEq(tokenWithLimitedSupply.balanceOf(user2), amounts[1], "Incorrect user2 balance after airdrop");
        assertEq(tokenWithLimitedSupply.totalSupply(), totalAirdroppedAmount, "Incorrect total supply after airdrop");
    }

    function testMintingWithUnlimitedSupplyDoesNotRevert() public {
    // Set up for unlimited supply
        uint256 mintAmount = tokenWithUnlimitedSupply.cap() + 1e18; // Exceeding the "cap"

        // Should not revert even if minting beyond the cap, due to unlimited supply flag
        tokenWithUnlimitedSupply.mint(user1, mintAmount);
        assertEq(tokenWithUnlimitedSupply.balanceOf(user1), mintAmount, "Minting should succeed with unlimited supply");
    }

    function testAccessControlEnforcement() public {
        // Example: Testing that only the pauser can pause/unpause
        vm.expectRevert();
        vm.prank(user1);
        tokenWithLimitedSupply.pause();

        // Now grant the role and try again
        tokenWithLimitedSupply.grantRole(tokenWithLimitedSupply.PAUSER_ROLE(), user1);
        vm.prank(user1);
        tokenWithLimitedSupply.pause(); // Should not revert now

        // Confirm the contract is paused
        assertTrue(tokenWithLimitedSupply.paused(),  "Contract should be paused");
    }

    function testTokenOperationsWhilePaused() public {
    uint256 mintAmount = 1e18; // Minting an amount for transfer tests
    tokenWithLimitedSupply.mint(address(this), mintAmount); // Ensure there are tokens to transfer

    // Pause the contract to test pausable transfers
    tokenWithLimitedSupply.pause();

    
    vm.expectRevert(); // Expect any revert
    tokenWithLimitedSupply.transfer(user1, mintAmount);

    // Unpause the contract and ensure operations can proceed
    tokenWithLimitedSupply.unpause();
    tokenWithLimitedSupply.transfer(user1, mintAmount); // This should succeed
    assertEq(tokenWithLimitedSupply.balanceOf(user1), mintAmount, "Transfer should succeed after unpausing");
}



}
