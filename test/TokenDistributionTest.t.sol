// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenDistribution.sol";
import "../src/MyERC20Token.sol";
import "./MockAggregatorV3.sol"; 

/// @title Tests for the TokenDistribution contract
/// @notice This test suite checks the main functionalities of the TokenDistribution contract
contract TokenDistributionTest is Test {
    TokenDistribution tokenDistribution;
    MyERC20Token token;
    MyERC20Token usdt;
    MockAggregatorV3 priceFeed;

    address owner = address(this);
    address buyer = address(0x2);
    address zeroAddress = address(0);

    /// @notice Setup function to initialize test contracts and set initial conditions
    function setUp() public {
        console.log("Deploying the ERC20 and TokenDistribution contracts");

        // Initialize tokens and price feed
        token = new MyERC20Token("Test Token", "TST", owner, owner, owner, owner, 1e24, false);
        usdt = new MyERC20Token("USDT Token", "USDT", owner, owner, owner, owner, 1e24, false);
        priceFeed = new MockAggregatorV3();

        // Deploy TokenDistribution with the initialized contracts and owner
        tokenDistribution = new TokenDistribution(
            address(token),
            address(usdt),
            address(priceFeed),
            owner
        );

        // Mint tokens to the distribution contract to simulate available supply
        token.mint(address(tokenDistribution), 1e24);
        console.log("Minted tokens to the distribution contract");

        // Mint USDT to the buyer to simulate buying power
        usdt.mint(buyer, 1e6 * 1e6);
        console.log("Minted USDT to the buyer");

        // Setup mock price feed to return $1 per USDT
        vm.mockCall(
            address(priceFeed),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(1, 1e8, block.timestamp, block.timestamp, 1)
        );
        console.log("Set up the mock price feed");
    }


    /// @notice Test the requirement for USDT approval before buying tokens
    function testFailBuyTokensWithoutApproval() public {
        console.log("Testing failure when buying tokens without prior approval");
        uint256 usdtToSpend = 100_000 * 1e6;  // Buyer wants to spend 100,000 USDT without approval

        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        tokenDistribution.buyTokens(usdtToSpend);
    }

    /// @notice Test updating the token price by the owner
    function testSetTokenPrice() public {
        console.log("Testing setting the token price");
        uint256 newPrice = 2 ether;  // Update the price to $2 per token

        vm.prank(owner);
        tokenDistribution.setTokenPriceUSD(newPrice);

        assertEq(tokenDistribution.tokenPriceUSD(), newPrice, "The token price should be updated to $2 per token");
    }

    /// @notice Test withdrawing USDT from the distribution contract by the owner
    function testWithdrawUSDT() public {
        console.log("Testing the withdrawal of USDT by the owner");
        uint256 amountToWithdraw = 100_000 * 1e6;  // Amount to withdraw

        // First, simulate a purchase to have some USDT in the contract
        vm.startPrank(buyer);
        usdt.approve(address(tokenDistribution), amountToWithdraw);
        tokenDistribution.buyTokens(amountToWithdraw);
        vm.stopPrank();

        // Withdraw USDT
        vm.prank(owner);
        tokenDistribution.withdrawUSDT(amountToWithdraw);

        assertEq(usdt.balanceOf(owner), amountToWithdraw, "Owner should receive the USDT withdrawn");
    }
    /// @notice Test buying tokens with sufficient USDT and approval
    function testBuyTokens() public {
        console.log("Testing token purchase functionality");
        uint256 usdtToSpend = 100_000 * 1e6;  // Buyer intends to spend 100,000 USDT
        uint256 expectedTokens = usdtToSpend;  // Should receive equal amount of tokens because price is 1 USDT per token

        // Approve the distribution contract to spend buyer's USDT
        vm.prank(buyer);
        usdt.approve(address(tokenDistribution), usdtToSpend);
        console.log("Approved token distribution to spend USDT");

        // Execute token purchase
        vm.prank(buyer);
        tokenDistribution.buyTokens(usdtToSpend);

        // Validate the outcome
        assertEq(token.balanceOf(buyer), expectedTokens, "Buyer should receive the correct amount of tokens");
        assertEq(usdt.balanceOf(address(tokenDistribution)), usdtToSpend, "TokenDistribution should receive the USDT");
    }
}
