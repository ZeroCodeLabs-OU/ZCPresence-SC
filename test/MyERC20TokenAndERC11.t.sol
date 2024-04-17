// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MyERC20Token.sol";
import "../src/erc11.sol"; 
import "../src/IERC20.sol";
import "../src/ERC1155Holder.sol";

contract MyERC20TokenAndERC11 is Test ,ERC1155Holder {
    MyERC20Token erc20Token;
    MyToken erc1155Token;
    address testUser = address(1);
    address deployer = address(this);

    function setUp() public {
        console.log("Deploying MyERC20Token contract...");
        erc20Token = new MyERC20Token(
            "PaymentToken",
            "PTKN",
            deployer,
            deployer,
            deployer,
            deployer,
            1e24,  // 1 million tokens with a cap
            false  // Not unlimited supply
        );
        console.log("MyERC20Token deployed:", address(erc20Token));

        erc20Token.mint(deployer, 1e24);
        console.log("Tokens minted to deployer.");
        erc20Token.transfer(testUser, 1e23);  // Transferring 100,000 tokens to testUser
        console.log("100,000 tokens transferred to testUser.");

        console.log("Deploying MyToken (ERC1155) contract...");
        erc1155Token = new MyToken();

        uint256 numTokenTypes = 3;  // Example of 3 different token types
        uint256 maxSupply = 1000;   // Total max supply for all token types

        // Define token quantities, assuming each type has an equal share of the maxSupply
        uint256[] memory tokenQuantities = new uint256[](maxSupply);
        for (uint256 i = 0; i < maxSupply; i++) {
            tokenQuantities[i] = 1; // Simplified quantity assignment
        }

        // Preparing reserved tokens for each type
        uint256[] memory reservedTokenIds = new uint256[](numTokenTypes);
        uint256[] memory reservedAmounts = new uint256[](numTokenTypes);
        for (uint256 i = 0; i < numTokenTypes; i++) {
            reservedTokenIds[i] = i + 1;  // Assuming token IDs are 1-based
            reservedAmounts[i] = 1;       // Reserve 1 unit for each token type
        }
        address defaultAdmin = address(0x2);

        // Initialize the ERC1155 contract
        erc1155Token.initialize(
            MyToken.DeploymentConfig({
                name: "ExampleNFT",
                symbol: "EXNFT",
                owner: defaultAdmin,
                maxSupply: maxSupply,
                tokenQuantity: tokenQuantities,
                tokensPerMint: 5,
                tokenPerPerson: 10,
                treasuryAddress: payable(deployer),
                WhitelistSigner: deployer,
                isSoulBound: false,
                openedition: false,
                trustedForwarder: deployer
            }),
            MyToken.RuntimeConfig({
                baseURI: "ipfs://exampleBaseUri/",
                metadataUpdatable: true,
                publicMintPrice: 1 ether,
                publicMintPriceFrozen: true,
                presaleMintPrice: 0.8 ether,
                presaleMintPriceFrozen: true,
                publicMintStart: block.timestamp,
                presaleMintStart: block.timestamp + 1 days,
                prerevealTokenURI: "ipfs://examplePreRevealUri/",
                presaleMerkleRoot: 0x0,
                royaltiesBps: 500,
                royaltiesAddress: deployer
            }),
            MyToken.ReservedMint({
                tokenIds: reservedTokenIds,
                amounts: reservedAmounts
            })
        );
        console.log("MyToken (ERC1155) initialized successfully.");

        vm.prank(defaultAdmin);
        erc1155Token.addToken(IERC20(address(erc20Token)), 1e18, false, address(0));  // 1 token costs 1 ERC20 token
        console.log("ERC20 token added as a payment method successfully.");
    }



  function testMintNFTWithERC20() public {
    vm.startPrank(testUser);

    console.log("Approving ERC1155 to spend user's ERC20 tokens...");
    erc20Token.approve(address(erc1155Token), 1e23);
    console.log("ERC20 tokens approved for ERC1155 contract.");

    uint256 nftIdBeforeMint = erc1155Token.totalSupply(0);
    uint256 userErc20BalanceBeforeMint = erc20Token.balanceOf(testUser);
    console.log("Before Minting: Total NFTs =", nftIdBeforeMint);
    console.log("Before Minting: User's ERC20 Balance =", userErc20BalanceBeforeMint);

    console.log("Attempting to mint NFT with ERC20 tokens...");
    erc1155Token.mintWithERC20(0, 1, 0, "");  // Mint 1 NFT of tokenId 0 using payment method 0

    uint256 nftIdAfterMint = erc1155Token.totalSupply(0);
    uint256 userErc20BalanceAfterMint = erc20Token.balanceOf(testUser);
    console.log("After Minting: Total NFTs =", nftIdAfterMint);
    console.log("After Minting: User's ERC20 Balance =", userErc20BalanceAfterMint);

    assertEq(nftIdAfterMint, nftIdBeforeMint + 1, "NFT should be minted");
    assertTrue(userErc20BalanceAfterMint < userErc20BalanceBeforeMint, "ERC20 tokens should be spent");

    vm.stopPrank();
}

}
