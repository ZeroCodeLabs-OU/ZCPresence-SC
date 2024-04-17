// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol"; // Import console for logging
import "../src/MyERC20Token.sol";
import "../src/NFTCollection.sol";
import "../src/IERC20.sol";

contract MyERC20TokenAndNFTCollectionTest is Test {
    MyERC20Token erc20Token;
    NFTCollection nftCollection;
    address testUser = address(1);
    address deployer = address(this);

    // Mock addresses for roles
    address defaultAdmin = address(0x2);
    address payable treasurer = payable(address(0x3));
    address forwarderAddress = address(0x4);
    address royaltiesAddress = address(0x5);

    function setUp() public {
    console.log("Deploying MyERC20Token contract...");
    erc20Token = new MyERC20Token(
        "PaymentToken",
        "PTKN",
        deployer,
        deployer,
        deployer,
        deployer,
        1e24, // 1 million tokens
        false
    );
    console.log("MyERC20Token deployed:", address(erc20Token));

    erc20Token.mint(deployer, 1e24); // Minting tokens for distribution
    console.log("Tokens minted to deployer.");
    erc20Token.transfer(testUser, 100 ether); // Transfer an amount that respects the cap
    console.log("Tokens transferred to testUser.");

    console.log("Deploying NFTCollection contract...");
    nftCollection = new NFTCollection();
    nftCollection.initialize(
        NFTCollection.DeploymentConfig({
                name: "ExampleNFT",
                symbol: "EXNFT",
                owner: defaultAdmin,
                maxSupply: 10000,
                reservedSupply: 100,
                tokensPerMint: 1,
                tokenPerPerson: 5,
                treasuryAddress: treasurer,
                WhitelistSigner: defaultAdmin,
                isSoulBound: false,
                trustedForwarder: forwarderAddress
            }),
        NFTCollection.RuntimeConfig({
                baseURI: "ipfs://exampleBaseUri/",
                metadataUpdatable: true,
                publicMintPrice: 1 ether,
                publicMintPriceFrozen: false,
                presaleMintPrice: 0.8 ether,
                presaleMintPriceFrozen: false,
                publicMintStart: block.timestamp , // Set to past to ensure minting is active
                presaleMintStart: block.timestamp , // Future date
                prerevealTokenURI: "ipfs://examplePreRevealUri/",
                presaleMerkleRoot: 0x0,
                royaltiesBps: 500,
                royaltiesAddress: address(this)
            })
    );
    console.log("NFTCollection initialized successfully.");

    vm.prank(defaultAdmin);
    nftCollection.addToken(IERC20(address(erc20Token)), 1 ether, false, address(0));
    console.log("ERC20 token added as a payment method successfully.");
}

function testMintNFTWithERC20() public {
    vm.warp(block.timestamp + 1 days); // Fast forward time to ensure minting is active

    vm.prank(testUser);
    erc20Token.approve(address(nftCollection), 100 ether); // Approve NFT contract to spend tokens
    console.log("ERC20 tokens approved for NFTCollection.");

    uint256 nftIdBeforeMint = nftCollection.totalSupply();
    uint256 userErc20BalanceBeforeMint = erc20Token.balanceOf(testUser);

    vm.prank(testUser); // Ensure testUser is set as msg.sender for mint operation
    try nftCollection.mintWithERC20(1, 0) {
        console.log("NFT minted successfully.");
    } catch Error(string memory reason) {
        console.log("Failed to mint NFT with ERC20:", reason);
    }

    uint256 nftIdAfterMint = nftCollection.totalSupply();
    uint256 userErc20BalanceAfterMint = erc20Token.balanceOf(testUser);

    assertEq(nftIdAfterMint, nftIdBeforeMint + 1, "NFT should be minted");
    assertTrue(userErc20BalanceAfterMint < userErc20BalanceBeforeMint, "ERC20 tokens should be spent");
}


}
