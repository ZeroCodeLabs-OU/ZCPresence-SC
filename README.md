
# Solidity Smart Contract Examples

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
