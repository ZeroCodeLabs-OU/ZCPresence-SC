
# Solidity Smart Contract Repository

This repository contains Solidity smart contracts for a token system using ERC20, ERC721, and ERC1155 standards, along with comprehensive tests using Foundry.

## Installation

To get started with this repository, you will need to install Foundry, a fast, portable, and modular toolkit for Ethereum application development written in Rust.

### Installing Foundry

You can install Foundry on macOS, Linux, or Windows by running the following command in your terminal:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

This command installs `forge`, Foundry's command-line tool for compiling and testing Solidity contracts.


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

The repository includes tests for ERC20, ERC721, and ERC1155 tokens, ensuring compliance with token standards and expected behaviors such as minting, pausing, and access control.

### Test Scripts

1. **MyERC20TokenTest.sol** - Tests the functionality of the `MyERC20Token` contract. It covers scenarios with both limited and unlimited token supplies, including minting, pausing, burning, and role management.

2. **MyERC20TokenAndERC11Test.sol** - Integrates testing of an ERC1155 token contract (`MyToken`) using ERC20 tokens for minting. This script tests the minting process using ERC20 tokens, ensuring that the contract handles token transfers and access control correctly.

3. **NFTMintWithERC20Test.sol** - Tests minting ERC721 tokens (`NFTCollection`) using ERC20 tokens (`MyERC20Token`). It verifies the interaction between ERC721 and ERC20 through minting processes and role-based access control.

### Running Tests

To run all tests, navigate to the root directory of the repository and execute:

```bash
forge test
```

To run a specific test file, use the following command:

```bash
forge test --match-path path/to/testfile.sol
```

For example, to run tests specifically for the ERC20 token scenarios:

```bash
forge test --match-path test/MyERC20TokenTest.sol
```

And for ERC721 minting tests:

```bash
forge test --match-path test/NFTMintWithERC20Test.sol
```

## Test Details

- **ERC20 Token Tests**: Verify functionalities such as minting, cap enforcement, role management, pausing, and compliance with the ERC20 standard.
- **ERC1155 Token Tests**: Focus on minting using ERC20 tokens, access control, and interaction with ERC1155 token standards.
- **ERC721 Token Tests**: Test the minting of NFTs using ERC20 tokens, ensuring correct functionality of the minting process, access control, and ERC721 compliance.

