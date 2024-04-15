// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MultisigTimelock} from "../src/MultisigTimelock.sol";
import {NFTCollection} from "../src/NFTCollection.sol";

contract DeployNFTCollection is Script {
    NFTCollection public collection;
    MultisigTimelock public multisigAddr;

    function run() external {
        // Define hardcoded addresses and values
        address defaultAdmin = address(0x123); // Example admin address
        address deployer = address(this); // Deployer's address (contract deployer)
        address payable treasurer = payable(address(0x456)); // Treasurer address
        address forwarderAddress = address(0x789); // Forwarder address for EIP-2771
        address royaltiesAddress = address(0xABC); // Address for royalties

        address[] memory owners = new address[](3);
        owners[0] = address(0xDEF); // Owner 1
        owners[1] = address(0x101112); // Owner 2
        owners[2] = address(0x131415); // Owner 3 (false owner for example)

        uint256 deployerPrivateKey = 0; // Example private key, not used in scripts
        
        // Deploy MultisigTimelock contract
        console.log("Deploying MultisigTimelock contract");
        multisigAddr = new MultisigTimelock(owners, 2, 24 hours); // 2 out of 3 owners with 24 hours delay
        console.log("Multisig address:", address(multisigAddr));
        
        // Deploy NFTCollection
        console.log("Deploying NFTCollection contract");
        collection = new NFTCollection();
        collection.initialize(
            NFTCollection.DeploymentConfig({
                name: "ZERO-CODE-NFT",
                symbol: "ZC-NFT",
                owner: defaultAdmin,
                maxSupply: 1000,
                reservedSupply: 500,
                tokensPerMint: 100,
                tokenPerPerson: 100,
                treasuryAddress: treasurer,
                WhitelistSigner: defaultAdmin,
                isSoulBound: false,
                trustedForwarder: forwarderAddress
            }),
            NFTCollection.RuntimeConfig({
                baseURI: "https://someurl/",
                metadataUpdatable: false,
                publicMintPrice: 1 ether,
                publicMintPriceFrozen: true,
                presaleMintPrice: 0.8 ether,
                presaleMintPriceFrozen: true,
                publicMintStart: block.timestamp + 1 days,
                presaleMintStart: block.timestamp,
                prerevealTokenURI: "https://ipfs.io/ipfs/",
                presaleMerkleRoot: 0x0,
                royaltiesBps: 500,
                royaltiesAddress: royaltiesAddress
            })
        );
        console.log("NFTCollection deployed to:", address(collection));
        
        // Additional deployment logic or tests can go here
    }
}
