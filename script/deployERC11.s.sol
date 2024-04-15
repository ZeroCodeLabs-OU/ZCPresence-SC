//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MultisigTimelock} from "../src/MultisigTimelock.sol";
import {MyToken} from "../src/erc11.sol";

contract deployERC11 is Script {
    MultisigTimelock public multisigAddr;
    MyToken public token;

    // PARTICIPANTS
    address defaultAdmin = vm.envAddress("DEFAULT_ADMIN"); //makeAddr("defaultAdmin");
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address account = vm.envAddress("ACCOUNT");
    address payable treasurer = payable(makeAddr("treasurer"));
    address forwarderAddress = makeAddr("forwarderAddress");
    address royaltiesAddress = makeAddr("royaltiesAddress");
    address[] owners = new address[](3);
    address owner1 = vm.envAddress("OWNER_1"); // makeAddr("owner1");
    address owner2 = vm.envAddress("OWNER_2"); // makeAddr("owner2");

    address owner3 = vm.envAddress("OWNER_3"); // FALSE OWNER

    function setUp() public {
        vm.startBroadcast(deployerPrivateKey);
        owners[0] = account;
        owners[1] = owner1; //vm.envAddress("OWNER_2");
        owners[2] = owner2; //vm.envAddress("OWNER_3");
        //
        console.log("Deployer address:", account);
        console.log(
            "MULTISIG-TIMELOCK OWNERS",
            owners[0],
            owners[1],
            owners[2]
        );

        uint256 timelock24h = 0;

        multisigAddr = new MultisigTimelock(owners, 3, timelock24h);
        console.log("Multisig address: %s", address(multisigAddr));

        //multisig contract owners
        address[] memory multisigOwners = multisigAddr.getOwners();
        console.log(
            "Multisig owners:",
            multisigOwners[0],
            multisigOwners[1],
            multisigOwners[2]
        );

        require(
            multisigOwners[0] == owners[0] &&
                multisigOwners[1] == owners[1] &&
                multisigOwners[2] == owners[2],
            "Multisig owners not equal to owners"
        );

        vm.stopBroadcast();

        // TOKEN DEPLOYMENT
        vm.startBroadcast(deployerPrivateKey);
        token = new MyToken();

        MyToken.DeploymentConfig memory deploymentConfig;
        MyToken.RuntimeConfig memory runtimeConfig;
        MyToken.ReservedMint memory reservedDetails;

        deploymentConfig = MyToken.DeploymentConfig({
            name: "ZC-Token",
            symbol: "ZCT",
            owner: account,
            maxSupply: 10000,
            tokenQuantity: new uint256[](10000),
            tokensPerMint: 50,
            tokenPerPerson: 5,
            treasuryAddress: treasurer,
            WhitelistSigner: account,
            isSoulBound: true,
            openedition: true,
            trustedForwarder: forwarderAddress
        });

        runtimeConfig = MyToken.RuntimeConfig({
            baseURI: "https://ipfs.io/ipfs/",
            metadataUpdatable: false,
            publicMintPrice: 100,
            publicMintPriceFrozen: true,
            presaleMintPrice: 100,
            presaleMintPriceFrozen: true,
            publicMintStart: 1694690807489,
            presaleMintStart: 1694690835616,
            prerevealTokenURI: "https://ipfs.io/ipfs/",
            presaleMerkleRoot: 0,
            royaltiesBps: 0,
            royaltiesAddress: royaltiesAddress
        });

        reservedDetails = MyToken.ReservedMint({
            tokenIds: new uint256[](10),
            amounts: new uint256[](10)
        });

        token.initialize(deploymentConfig, runtimeConfig, reservedDetails);

        vm.stopBroadcast();
    }

    function run() external {
        vm.startBroadcast(account);
        address currentOwner = token.owner();
        console.log("Token address: %s", address(token));
        console.log("Token owner: %s", currentOwner);
        console.log("Token name: %s", token.name());

        require(
            token.hasRole(token.ADMIN_ROLE(), account),
            "Default admin is not admin"
        );

        token.transferOwnership(address(multisigAddr));

        uint256 timelockPeriod = multisigAddr.getTimelockPeriod();
        console.log("Timelock period: %s", timelockPeriod);

        require(
            token.hasRole(token.ADMIN_ROLE(), address(multisigAddr)),
            "Multisig address is not admin"
        );

        address currentOwner2 = token.owner();
        console.log("Multisif Token owner: %s", currentOwner2);

        vm.stopBroadcast();
    }
}
