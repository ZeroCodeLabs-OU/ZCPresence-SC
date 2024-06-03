// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenDistribution.sol";  

contract DeployTokenDistribution is Script {
    function run() external { 
        // Configuration
        address tokenAddress = 0x8db9B7C4e93e6e1F5cC1754D6a89e0D5ad276af9;  
        address usdtAddress = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; 
        address priceFeedAddress = 0x0A6513e40db6EB1b165753AD52E80663aeA50545;  
        address initialOwner = vm.envAddress("DEPLOYER_ADDRESS");  

        // Start deployment
        vm.startBroadcast();

        TokenDistribution tokenDist = new TokenDistribution(
            tokenAddress,
            usdtAddress,
            priceFeedAddress,
            initialOwner
        );

        console.log("TokenDistribution deployed to:", address(tokenDist));

        uint256 depositAmount = 1_00 * 1e18;  
        IERC20(tokenAddress).approve(address(tokenDist), depositAmount);
        tokenDist.depositTokens(depositAmount);

        uint256 newPriceUSD = 1 * 1e18;  // $1 per token
        tokenDist.setTokenPriceUSD(newPriceUSD);

        vm.stopBroadcast();
    }
}
