// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/erc11.sol";  // Ensure this path correctly points to your contract

contract InitializeMyTokenScript is Script {
    function run() external {
        vm.startBroadcast();

        // Specify the already deployed contract address here
        address contractAddress = 0x444a048933AB9EEc534DA2A2F5f765DAaB5f3ba6;

        // Attach the existing contract interface to interact with it
        MyToken erc1155Token = MyToken(contractAddress);

        console.log("Connected to MyToken at:", contractAddress);

        
        address initialOwner = vm.envAddress("DEPLOYER_ADDRESS");

        uint256 numTokenTypes = 3;  
        uint256 maxSupply = 1000;   

        uint256[] memory tokenQuantities = new uint256[](maxSupply);
        for (uint256 i = 0; i < maxSupply; i++) {
            tokenQuantities[i] = 1;
        }

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

        MyToken.RuntimeConfig memory runtimeConfig = MyToken.RuntimeConfig({
            baseURI: "ipfs://exampleBaseUri/",
            metadataUpdatable: true,
            publicMintPrice: 0.3 ether,
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

        uint256[] memory reservedTokenIds = new uint256[](numTokenTypes);
        uint256[] memory reservedAmounts = new uint256[](numTokenTypes);
        for (uint256 i = 0; i < numTokenTypes; i++) {
            reservedTokenIds[i] = i + 1;  
            reservedAmounts[i] = 1;       
        }

        MyToken.ReservedMint memory reservedMint = MyToken.ReservedMint({
            tokenIds: reservedTokenIds,
            amounts: reservedAmounts
        });

        console.log("Initializing MyToken with deployment, runtime, and reserved mint configurations...");
        erc1155Token.initialize(deploymentConfig, runtimeConfig, reservedMint);

        console.log("MyToken (ERC1155) initialized at:", contractAddress);

        vm.stopBroadcast();
    }
}
