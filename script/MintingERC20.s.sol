// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MyERC20Token.sol";

contract DeployAndMintERC20 is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the MyERC20Token contract
        MyERC20Token token = new MyERC20Token(
            "MyToken", // Token name
            "MTK",     // Token symbol
            msg.sender, // Default admin
            address(0), // Pauser address
            msg.sender, // Minter address
            msg.sender, // Airdropper address
            1e24,       // Cap
            true        // Unlimited supply
        );

        // Mint tokens to a specific address
        token.mint(msg.sender, 1e18); // Mint 1 token for simplicity
        
        vm.stopBroadcast();
    }
}
