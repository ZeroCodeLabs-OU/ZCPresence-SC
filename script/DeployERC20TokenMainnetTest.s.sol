// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MyERC20Token.sol"; // Ensure this import path is correct

contract DeployERC20TokenMainnetTest is Script {
    function run() external {
        vm.startBroadcast();

        // Parameters for token creation
        string memory name = "ZCTEST";
        string memory symbol = "ZCT";
        uint256 cap = 1000000 * 1e18; // 1 million tokens, with 18 decimal places
        bool isSupplyUnlimited = false;

        // Using a fixed address for roles for demonstration; replace with actual addresses
        address defaultAdmin = vm.envAddress("DEPLOYER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        address minter = vm.envAddress("MINTER_ADDRESS");
        address airdropper = vm.envAddress("AIRDROPPER_ADDRESS");

        // Deploy the token
        MyERC20Token token = new MyERC20Token(
            name,
            symbol,
            defaultAdmin,
            pauser,
            minter,
            airdropper,
            cap,
            isSupplyUnlimited
        );

        console.log("ZCTEST deployed to:", address(token));

        // Example minting to the deployer (can be replaced or removed as needed)
        token.mint(defaultAdmin, 100000 * 1e18); // Mint 100,000 tokens

        vm.stopBroadcast();
    }
}
