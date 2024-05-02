// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenDistribution.sol";  // Update the path according to your project structure

contract DeployTokenDistribution is Script {
    function run() external { 
        // Configuration
        address tokenAddress = 0xf93A0FCdE9304CABefb004540838FF5234789429;  // Replace with your deployed token address
        address usdtAddress = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;  // Mainnet USDT address on Polygon
        address priceFeedAddress = 0x0A6513e40db6EB1b165753AD52E80663aeA50545;  // USDT/USD Chainlink Price Feed on Polygon
        address initialOwner = vm.envAddress("DEPLOYER_ADDRESS");  // Using environment variable for owner address

        // Start deployment
        vm.startBroadcast();

        TokenDistribution tokenDist = new TokenDistribution(
            tokenAddress,
            usdtAddress,
            priceFeedAddress,
            initialOwner
        );

        console.log("TokenDistribution deployed to:", address(tokenDist));

        // Deposit tokens (example amount)
        uint256 depositAmount = 1_00 * 1e18;  // Adjust based on your token's decimals
        IERC20(tokenAddress).approve(address(tokenDist), depositAmount);
        tokenDist.depositTokens(depositAmount);

        // Set token price in USD (example price)
        uint256 newPriceUSD = 1 * 1e18;  // $1 per token
        tokenDist.setTokenPriceUSD(newPriceUSD);

        vm.stopBroadcast();
    }
}
