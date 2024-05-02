// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TokenDistribution.sol";
import "../src/IERC20.sol";

contract widthdrawUSDT is Script {
    address private constant TOKEN_DISTRIBUTION_ADDRESS =0xA531F4E0b54B7FFBc8F925dE01A57cDE94Ffd7D5; 
    address private constant USDT_ADDRESS = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; 

    function run() public {
        vm.startBroadcast();

        uint256 usdtAmount = 4 * 10**6; 

        
        TokenDistribution tokenDistribution = TokenDistribution(TOKEN_DISTRIBUTION_ADDRESS);

        
        tokenDistribution.withdrawUSDT(usdtAmount);

        vm.stopBroadcast();
    }
}
