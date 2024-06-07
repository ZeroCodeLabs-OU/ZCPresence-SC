// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MiningPool {
    uint256 public constant MAX_PRS_SUPPLY = 1000000;  // Maximum PRS supply
    uint256 public constant INITIAL_DIFFICULTY_INDEX = 1000; // Initial difficulty index
    
    uint256 public mint_tx; // Number of mint transactions
    uint256 public revoke_tx; // Number of revoke transactions
    uint256 public totalNFTTransactions; // Total NFT transactions (mint + revoke)
    uint256 public totalMinedPRS; // Total mined PRS
    uint256 public difficultyIndex = INITIAL_DIFFICULTY_INDEX; // Difficulty index
    uint256 public prsFactor; // Fraction of transaction fee converted to PRS tokens
    mapping(uint256 => uint256) public tokenPrices; // Tracking token prices per transaction

    address public admin; // Admin address for managing critical functions

    event MiningDetailsUpdated(uint256 minedPRS, uint256 transactionCount);

    constructor(uint256 _initialPrsFactor) {
        admin = msg.sender;
        prsFactor = _initialPrsFactor;
        mint_tx = 0;
        revoke_tx = 0;
        totalNFTTransactions = 0;
        totalMinedPRS = 0;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this operation");
        _;
    }

    // External function to be called by the FeeDistribution contract
    function recordNFTTransaction(uint256 transactionFee) external {
        totalNFTTransactions = mint_tx + revoke_tx;
        uint256 prsFract = transactionFee * prsFactor / 100;
        uint256 minedPRS = MAX_PRS_SUPPLY / (difficultyIndex * totalNFTTransactions);
        totalMinedPRS += minedPRS;

        require(totalMinedPRS <= MAX_PRS_SUPPLY, "Exceeds maximum PRS supply");

        tokenPrices[totalNFTTransactions] = prsFract / minedPRS;
        emit MiningDetailsUpdated(minedPRS, totalNFTTransactions);
    }

    // Admin function to adjust the mining difficulty index
    function adjustDifficultyIndex(uint256 newDifficultyIndex) public onlyAdmin {
        difficultyIndex = newDifficultyIndex;
    }

    // Calculate average token value based on historical data
    function calculateAverageTokenValue() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 1; i <= totalNFTTransactions; i++) {
            sum += tokenPrices[i];
        }
        return sum / totalNFTTransactions;
    }

    // Calculate the face value of the token
    function calculateTokenFaceValue(uint256 supplyDemandIndex) public view returns (uint256) {
        uint256 avgTokenValue = calculateAverageTokenValue();
        return avgTokenValue * supplyDemandIndex;
    }

    // Function to update PRS factor
    function updatePrsFactor(uint256 newPrsFactor) public onlyAdmin {
        prsFactor = newPrsFactor;
    }

    // Function to record mint transactions, called by the NFT contract
    function recordMintTx() external {
        mint_tx++;
    }

    // Function to record revoke transactions, called by the NFT contract
    function recordRevokeTx() external {
        revoke_tx++;
    }

    // Function to get total mined PRS tokens
    function getTotalMinedPRS() external view returns (uint256) {
        return totalMinedPRS;
    }
}
