// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenDistribution.sol";
import "../src/IERC20.sol";

contract BuyTokensScript is Script {
    address private constant TOKEN_DISTRIBUTION_ADDRESS =0xcB0aFD1A7b17E0C85740156eFe3F0D32a7fcc0Dd;
    address private constant USDT_ADDRESS = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; 

    function run() public {
        vm.startBroadcast();

        uint256 usdtAmount = 2 * 10**6; 
        IERC20 usdt = IERC20(USDT_ADDRESS);
        TokenDistribution tokenDistribution = TokenDistribution(TOKEN_DISTRIBUTION_ADDRESS);

        if (usdt.allowance(address(this), TOKEN_DISTRIBUTION_ADDRESS) < usdtAmount) {
            require(usdt.approve(TOKEN_DISTRIBUTION_ADDRESS, usdtAmount), "USDT approve failed.");
        }

        // Call the buyTokens function
        tokenDistribution.buyTokens(usdtAmount);

        vm.stopBroadcast();
    }
}
