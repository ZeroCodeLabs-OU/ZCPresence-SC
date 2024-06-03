// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/erc11.sol";  // Make sure this path correctly points to your ERC1155 contract file

contract test is Script {
    function run() external {
        vm.startBroadcast();

        address contractAddress = 0x444a048933AB9EEc534DA2A2F5f765DAaB5f3ba6;
        MyToken erc1155Token = MyToken(contractAddress);

        address initialOwner = 0x6FEC51b4a3F9c68E45822B6C8aDcac3A2863f133;
        uint256 numTokenTypes = 3; // Three types of tokens
        uint256 maxSupply = 9; // Total max supply for all token types

        uint256[] memory tokenQuantities = new uint256[](numTokenTypes);
        for (uint256 i = 0; i < numTokenTypes; i++) {
            tokenQuantities[i] = 3; // Three tokens per type, assuming types are 0, 1, 2
        }


        MyToken.DeploymentConfig memory deploymentConfig = MyToken.DeploymentConfig({
            name: "ExampleNFT",
            symbol: "EXNFT",
            owner: initialOwner,
            maxSupply: maxSupply,
            tokenQuantity: tokenQuantities,
            tokensPerMint: 3,
            tokenPerPerson: 3,
            treasuryAddress: payable(initialOwner),
            WhitelistSigner: initialOwner,
            isSoulBound: false,
            openedition: false,
            trustedForwarder: initialOwner
        });

        MyToken.RuntimeConfig memory runtimeConfig = MyToken.RuntimeConfig({
            baseURI: "ipfs://exampleBaseUri/",
            metadataUpdatable: true,
            publicMintPrice: 0.3 ether,
            publicMintPriceFrozen: true,
            presaleMintPrice: 0.1 ether,
            presaleMintPriceFrozen: true,
            publicMintStart: block.timestamp+1 days,
            presaleMintStart: block.timestamp,
            prerevealTokenURI: "ipfs://examplePreRevealUri/",
            presaleMerkleRoot: 0x0,
            royaltiesBps: 500,
            royaltiesAddress: initialOwner
        });

        uint256[] memory reservedTokenIds = new uint256[](numTokenTypes);
        uint256[] memory reservedAmounts = new uint256[](numTokenTypes);
        for (uint256 i = 0; i < numTokenTypes; i++) {
            reservedTokenIds[i] = i; // Starting from 0
            reservedAmounts[i] = 1;  // Reserving one unit per token type
        }


        MyToken.ReservedMint memory reservedMint = MyToken.ReservedMint({
            tokenIds: reservedTokenIds,
            amounts: reservedAmounts
        });

        // Initializing the contract
        console.log("Initializing MyToken...");
        erc1155Token.initialize(deploymentConfig, runtimeConfig, reservedMint);
        console.log("MyToken initialized successfully.");

        vm.stopBroadcast();
    }
}
