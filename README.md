
# Presence SocialFi (PRS Token) Smart-Contracts by Zero-Code

## Overview
The Presence SocialFi Protocol (PRS) aims to revolutionize local consumer interactions and engagements by leveraging blockchain technology. This repository is part of a broader Zero-Code initiative to build the Presence SocialFi protocol on the Polygon network. Our goal is to address the shortcomings of current social platforms by fostering genuine foot traffic and personal connections. By combining social discovery mechanisms with a merchant-focused economy, Presence empowers users to locate industry peers and explore local venues like coworking spaces thereby directly supporting local businesses and service providers.

This repository is central to building the Presence SocialFi protocol on the Polygon network, particularly in advancing our blockchain-based merchant loyalty programs. Our open-source approach reflects a commitment to transparency and community-driven development, allowing global contributors to participate in shaping a decentralized application that serves digital nomads, expats, and local merchants ranging from coffee shops, entertainments and dinnings, to personal trainers or yoga instructors.


## Purpose of the Repository
This repository has been created to house the essential building blocks of the Presence SocialFi protocol. It contains various smart contracts designed to operate within the Polygon network, facilitating a range of functionalities from economic transactions to governance mechanisms. The decision to make this repository open-source stems from our commitment to community involvement and the ethos of decentralization, allowing developers and stakeholders worldwide to contribute to and scrutinize the protocol's development.

## Contents of the Repository
Below is an overview of the smart contracts included in this repository, along with their specific functions within the Presence SocialFi protocol:

### ERC1155 Smart Contracts
Purpose: Utilized for creating vouchers and gift cards for local consumers, enhancing the engagement and rewards mechanisms for protocol participants.
### ERC20 Smart Contracts
Purpose: Serves as the backbone for the protocol's economy, used to reward engaged users, collect fees related to offer creation and redemption, and manage the cashing out of rewards.
### ERC11 Smart Contracts
- **Burning Mechanism:** Allows for the on-chain redeeming of ERC1155 tokens by burning them, facilitating a robust transaction lifecycle.
- **Currency Selection & Minting (Chainlink Integration):** Facilitates choosing the currency for minting tokens (USDT, MATIC, PRS ERC20).
- **Royalties & Market Controls:** Manages royalties on second market sales and controls trading mechanisms like locking, unlocking, and setting up Soulbound Tokens. It also supports updating token metadata stored on IPFS.
### Biconomy Integrations
- **AA (Trench 3):** Enables and disables gasless creation of the ERC1155 smart contract, reducing the barrier for entry regarding transaction costs.
- **Gasless API:** Supports gasless minting, airdropping, and redeeming of ERC1155 tokens, enhancing user experience and accessibility.
- **OnRamp Service Partner (Trench 3):** Facilitates the direct purchase of USDT and MATIC with fiat currencies, integrating traditional financial systems with blockchain technology.
### Token Distribution Mechanisms
- **TokenDistribution (Chainlink Integration):** Allows users to select the currency for buying tokens (USDT, MATIC, PRS ERC20) and supports purchasing PresenceCoin ERC20 using these currencies.
## Multisig Contracts
- **Purpose:** Enables decentralized protocol governance, allowing multiple parties to manage and approve significant actions within the protocol, ensuring security and distributed control.
## Royalty Splitter Contracts
- **Purpose:** Automates the distribution of royalties among multiple parties from second market sales, ensuring fairness and transparency in profit-sharing.
## Protocol Distribution (Trench 3)
- **Purpose:** Manages the collection of protocol fees, depositing them into a treasury address, which supports the sustainability and financial operations of the protocol.

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
