// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MyERC20Token.sol"; // Update the path according to your project structure

contract DeployMyERC20Token is Script {
    // Deploy the contract and return its address for potential use in tests or verification
    function run() external returns (address) {
        // Hardcoded deployment parameters
        string memory name = "ExampleToken";
        string memory symbol = "EXT";
        address defaultAdmin = vm.addr(1); // Using vm.addr to simulate an address for Anvil
        address pauser = vm.addr(2);
        address minter = vm.addr(3);
        address airdropper = vm.addr(4);
        uint256 capacity = 1000000;
        bool unlimitedSupply = false;

        vm.startBroadcast();

        MyERC20Token token = new MyERC20Token(
            name,
            symbol,
            defaultAdmin,
            pauser,
            minter,
            airdropper,
            capacity,
            unlimitedSupply
        );

        console.log("MyToken deployed to:", address(token));

        vm.stopBroadcast();

        return address(token);
    }
}
