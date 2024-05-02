// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenDistribution.sol";
import "../src/IERC20.sol";

contract BuyTokensScript is Script {
    // Define the addresses of the contracts (replace placeholders with actual addresses)
    address private constant TOKEN_DISTRIBUTION_ADDRESS =0xcB0aFD1A7b17E0C85740156eFe3F0D32a7fcc0Dd; // <- Replace with your contract address
    address private constant USDT_ADDRESS = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // <- Replace with your USDT token address

    function run() public {
        vm.startBroadcast();

        // Define the amount of USDT to spend (e.g., 2 USDT with 6 decimal places)
        uint256 usdtAmount = 2 * 10**6; // 2 USDT for USDT token with 6 decimals

        // Fetch contract instances
        IERC20 usdt = IERC20(USDT_ADDRESS);
        TokenDistribution tokenDistribution = TokenDistribution(TOKEN_DISTRIBUTION_ADDRESS);

        // Approve the TokenDistribution contract to spend your USDT
        if (usdt.allowance(address(this), TOKEN_DISTRIBUTION_ADDRESS) < usdtAmount) {
            require(usdt.approve(TOKEN_DISTRIBUTION_ADDRESS, usdtAmount), "USDT approve failed.");
        }

        // Call the buyTokens function
        tokenDistribution.buyTokens(usdtAmount);

        vm.stopBroadcast();
    }
}
