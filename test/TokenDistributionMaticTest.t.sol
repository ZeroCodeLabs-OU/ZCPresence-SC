// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyERC20Token.sol";
import "../src/TokenDistribution.sol";
import "../src/IERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract TokenDistributionTest is Test {
   TokenDistribution tokenDistribution;
    MyERC20Token token;
    IERC20 usdt;
    AggregatorV3Interface priceFeed;

    address owner;
    address buyer;

    function setUp() public {
        // Log the environment variable for owner and buyer
        console.log("Owner address from env:", vm.envAddress("DEPLOYER_ADDRESS"));
        console.log("Buyer address from env:", vm.envAddress("BUYER_ADDRESS"));

        // Assigning addresses from environment variables
        owner = vm.envAddress("DEPLOYER_ADDRESS");
        buyer = vm.envAddress("BUYER_ADDRESS");

        // Deploy the token contract with initial roles
        token = new MyERC20Token(
            "Distributed Token", "DTK",
            owner, owner, owner, owner,
            1000000 * 1e18, false
        );

        // Ensure owner has all necessary roles
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), owner);
        token.grantRole(token.MINTER_ROLE(), owner);
        token.grantRole(token.PAUSER_ROLE(), owner);

        // Deploy the TokenDistribution contract
        tokenDistribution = new TokenDistribution(
            address(token),
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F, // Real USDT on Polygon
            0x0A6513e40db6EB1b165753AD52E80663aeA50545, // Real Chainlink Price Feed for USD/USDT
            owner
        );

        // Assume the USDT has been bought and is already in the buyer's wallet
        // Log the initial setup completion
        console.log("Setup complete. Roles assigned, and Token Distribution is deployed.");
    }

    function testBuyTokens() public {
        uint256 usdtToSpend = 2 * 1e6;  // Buyer has 2 USDT to spend
        usdt.approve(address(tokenDistribution), usdtToSpend);

        vm.prank(buyer);
        tokenDistribution.buyTokens(usdtToSpend);

        uint256 expectedTokens = calculateExpectedTokens(usdtToSpend);
        assertEq(token.balanceOf(buyer), expectedTokens, "Buyer should receive the correct amount of tokens");
        assertEq(usdt.balanceOf(address(tokenDistribution)), usdtToSpend, "TokenDistribution should receive the USDT");
    }

    function calculateExpectedTokens(uint256 usdtAmount) internal returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint256 usdToTokenAmount = usdtAmount * uint256(price) / 1e8; // Convert USDT to equivalent USD
        return usdToTokenAmount * 1e18 / tokenDistribution.tokenPriceUSD(); // Determine tokens to buy
    }

    function testWithdrawUSDT() public {
        // Assume there is USDT in the TokenDistribution contract from previous tests
        uint256 amountToWithdraw = usdt.balanceOf(address(tokenDistribution));

        vm.prank(owner);
        tokenDistribution.withdrawUSDT(amountToWithdraw);

        assertEq(usdt.balanceOf(owner), amountToWithdraw, "Owner should receive the USDT withdrawn");
    }
}
