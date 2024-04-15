// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MultisigTimelock.sol";

// forge script script/NFT.s.sol:MyScript --fork-url http://localhost:8545 --broadcast

contract MultisigScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // console.log("Deployer private key:", deployerPrivateKey);
        address account = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", account);

        vm.startBroadcast(deployerPrivateKey);

        address[] memory owners = new address[](3);
        owners[0] = account;
        owners[1] = vm.envAddress("OWNER_2");
        owners[2] = vm.envAddress("OWNER_3");

        console.log("Owners:", owners[0], owners[1], owners[2]);

        MultisigTimelock c = new MultisigTimelock(owners, 3, 86400);

        console.log("Contract address: %s", address(c));

        address[] memory owners2 = c.getOwners();
        console.log("Owners:", owners2[0], owners2[1], owners2[2]);

        uint256 txId = c.submitTransaction(account, 1000, "0x");
        console.log("Transaction ID:", txId);

        uint256 confirmCount = c.getConfirmationCount(txId);
        console.log("Confirmations Count:", confirmCount);

        uint256 bal = c.getWalletBalance();
        console.log("Wallet balance:", bal);

        uint256 confirmations = c.getConfirmationCount(txId);

        console.log("Confirmations:", confirmations);

        vm.stopBroadcast();
    }
}
