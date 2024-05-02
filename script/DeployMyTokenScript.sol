// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/erc11.sol"; // Update this path to the correct location of your ERC1155 contract file

contract DeployMyTokenScript is Script {
    function run() external {
        vm.startBroadcast();

        // The deployer address can be an environment variable or hardcoded for specific cases
        address initialOwner = vm.envAddress("DEPLOYER_ADDRESS");

        // Deploy the ERC1155 contract
        console.log("Deploying MyToken (ERC1155) contract...");
        MyToken erc1155Token = new MyToken();

        uint256 numTokenTypes = 3;  // Example of 3 different token types
        uint256 maxSupply = 1000;   // Total max supply for all token types

        // Define token quantities, assuming each type has an equal share of the maxSupply
        uint256[] memory tokenQuantities = new uint256[](numTokenTypes);
        for (uint256 i = 0; i < numTokenTypes; i++) {
            tokenQuantities[i] = maxSupply / numTokenTypes; // Equal share of the maxSupply for each token type
        }

        // Preparing reserved tokens for each type
        uint256[] memory reservedTokenIds = new uint256[](numTokenTypes);
        uint256[] memory reservedAmounts = new uint256[](numTokenTypes);
        for (uint256 i = 0; i < numTokenTypes; i++) {
            reservedTokenIds[i] = i + 1;  // Assuming token IDs are 1-based
            reservedAmounts[i] = 1;       // Reserve 1 unit for each token type
        }

        // Initial configuration setup for your ERC1155 token
        MyToken.DeploymentConfig memory deploymentConfig = MyToken.DeploymentConfig({
            name: "ExampleNFT",
            symbol: "EXNFT",
            owner: initialOwner,
            maxSupply: maxSupply,
            tokenQuantity: tokenQuantities,
            tokensPerMint: 5,
            tokenPerPerson: 10,
            treasuryAddress: payable(initialOwner),
            WhitelistSigner: initialOwner,
            isSoulBound: false,
            openedition: false,
            trustedForwarder: initialOwner
        });

        // Runtime configuration for your ERC1155 token
        MyToken.RuntimeConfig memory runtimeConfig = MyToken.RuntimeConfig({
            baseURI: "ipfs://exampleBaseUri/",
            metadataUpdatable: true,
            publicMintPrice: 0.2 ether,
            publicMintPriceFrozen: true,
            presaleMintPrice: 0.1 ether,
            presaleMintPriceFrozen: true,
            publicMintStart: block.timestamp,
            presaleMintStart: block.timestamp + 1 days,
            prerevealTokenURI: "ipfs://examplePreRevealUri/",
            presaleMerkleRoot: 0x0,
            royaltiesBps: 500,
            royaltiesAddress: initialOwner
        });

        // Reserved Mint configuration
        MyToken.ReservedMint memory reservedMint = MyToken.ReservedMint({
            tokenIds: reservedTokenIds,
            amounts: reservedAmounts
        });

        // Initialize the contract with the configurations
        console.log("Initializing MyToken with deployment and runtime configurations...");
        erc1155Token.initialize(deploymentConfig, runtimeConfig, reservedMint);

        console.log("MyToken (ERC1155) deployed and initialized at:", address(erc1155Token));

        vm.stopBroadcast();
    }
}
