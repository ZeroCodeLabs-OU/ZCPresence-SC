// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/erc11.sol"; 

contract DeployMyTokenScript is Script {
    function run() external {
        vm.startBroadcast();

        address initialOwner = vm.envAddress("DEPLOYER_ADDRESS");

        console.log("Deploying MyToken (ERC1155) contract...");
        MyToken erc1155Token = new MyToken();

        // uint256 numTokenTypes = 3;  
        // uint256 maxSupply = 1000;   

        // // Define token quantities, assuming each type has an equal share of the maxSupply
        // uint256[] memory tokenQuantities = new uint256[](maxSupply);
        // for (uint256 i = 0; i < maxSupply; i++) {
        //     tokenQuantities[i] = 1; // Simplified quantity assignment
        // }

        // // Preparing reserved tokens for each type
        // uint256[] memory reservedTokenIds = new uint256[](numTokenTypes);
        // uint256[] memory reservedAmounts = new uint256[](numTokenTypes);
        // for (uint256 i = 0; i < numTokenTypes; i++) {
        //     reservedTokenIds[i] = i + 1;  
        //     reservedAmounts[i] = 1;       
        // }

        // // Initial configuration setup for your ERC1155 token
        // MyToken.DeploymentConfig memory deploymentConfig = MyToken.DeploymentConfig({
        //     name: "ExampleNFT",
        //     symbol: "EXNFT",
        //     owner: initialOwner,
        //     maxSupply: maxSupply,
        //     tokenQuantity: tokenQuantities,
        //     tokensPerMint: 5,
        //     tokenPerPerson: 10,
        //     treasuryAddress: payable(initialOwner),
        //     WhitelistSigner: initialOwner,
        //     isSoulBound: false,
        //     openedition: false,
        //     trustedForwarder: initialOwner
        // });

        // // Runtime configuration for your ERC1155 token
        // MyToken.RuntimeConfig memory runtimeConfig = MyToken.RuntimeConfig({
        //     baseURI: "ipfs://exampleBaseUri/",
        //     metadataUpdatable: true,
        //     publicMintPrice: 0.3 ether,
        //     publicMintPriceFrozen: true,
        //     presaleMintPrice: 0.1 ether,
        //     presaleMintPriceFrozen: true,
        //     publicMintStart: block.timestamp,
        //     presaleMintStart: block.timestamp + 1 days,
        //     prerevealTokenURI: "ipfs://examplePreRevealUri/",
        //     presaleMerkleRoot: 0x0,
        //     royaltiesBps: 500,
        //     royaltiesAddress: initialOwner
        // });

        // // Reserved Mint configuration
        // MyToken.ReservedMint memory reservedMint = MyToken.ReservedMint({
        //     tokenIds: reservedTokenIds,
        //     amounts: reservedAmounts
        // });

        // // Initialize the contract with the configurations
        // console.log("Initializing MyToken with deployment and runtime configurations...");
        // erc1155Token.initialize(deploymentConfig, runtimeConfig, reservedMint);

        // console.log("MyToken (ERC1155) deployed and initialized at:", address(erc1155Token));

        vm.stopBroadcast();
    }
}
