
# Presence SocialFi (PRS Token) Smart-Contracts by Zero-Code

## Introduction
Why we created this repository? Context of building Presence SocialFi protocol using Polygon network in an opensource matter
What does this repository contain? Smart-contracts that are used in the Presence SocialFi protocol (list it, and describe what is it used for)
- ERC1155: will be used to create vouchers and giftcards for Local consumers
- ERC20: will be used by the protocol to reward engaged users and collect fees on offer creation and redeeming as well as cashing out rewards) 
- ERC11: Burning mechanism for onchain redeeming of ERC1155 tokens
- Biconomy AA (Trench 3): Enables and Disable Gasless creation of the ERC1155 smart-contract
- Biconomy Gasless API: Enable and Disable Gasless minting, airdroping & redeeming of the ERC1155 tokens
- ERC11/Chainlink: Choosing the currency to mint token (USDT, MATIC, PRS ERC20)
- TokenDistribution/Chainlink: Choosing the currency to buy token (USDT, MATIC, PRS ERC20)
- Biconomy OnRamp Service Partner (Trench 3): OnRamp Buying of USDT, MATIC with FIAT
- TokenDistribution: Buy PresenceCoin ERC20 with USDT or MATIC
- ERC11: Set royalties on second market sales of ERC 1155 Tokens
- Royalty Splitter: Split the royalties between multiple parties on second market sales of ERC 1155 Tokens
- ERC11: Lock & Unlock Second market trade (Soulbound Token)
- ERC11: Enables whitelisting & presales
- ERC11: Enables updating token’s IPFS
- ProtocolDestribution (Trench 3): Enable and Disable collection Protocol fees in the treasuring address
- Multisig: Enables the Decentralisation of the protocol governance

## Installation

This repository uses [Foundry](https://book.getfoundry.sh/) for smart contract development. Foundry is a fast, portable, and modular toolkit for Ethereum application development.

### Prerequisites

- Install Foundry:
  ```sh
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

- Install Chainlink and OpenZeppelin dependencies:
  ```sh
  forge install smartcontractkit/chainlink
  forge install OpenZeppelin/openzeppelin-contracts
  ```

### Setup

After cloning the repository and navigating to the project directory, you can install the required dependencies:

```sh
forge install
```

## Testing

This repository includes several test scripts for testing the functionality of ERC20 and ERC1155 tokens using Foundry.

### Test Scripts

- `MyERC20Token.t.sol`: Tests various functionalities of the ERC20 token including minting, transfer, and permission handling.
- `MyERC20TokenAndERC11.t.sol`: Demonstrates minting ERC1155 NFTs using ERC20 tokens as payment.
- `MyERC20TokenAndNFTCollectionTest.t.sol`: Demonstrates minting ERC721 NFTs using ERC20 tokens as payment.

### Running Tests

To run all tests:

```sh
forge test
```

To run individual test files:

- For ERC20 token tests:
  ```sh
  forge test --match-path test/MyERC20Token.t.sol
  ```

- For ERC1155 token tests:
  ```sh
  forge test --match-path test/MyERC20TokenAndERC11.t.sol
  ```

- For NFT minting with ERC20 tests:
  ```sh
  forge test --match-path test/MyERC20TokenAndNFTCollectionTest.t.sol
  ```

## Additional Information

Each test file contains multiple scenarios to ensure the smart contracts behave as expected across different use cases. Look into the test files for detailed descriptions of each test case.
