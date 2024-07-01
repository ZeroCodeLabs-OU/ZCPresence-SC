// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./AccessControl.sol";
import "./ReentrancyGuard.sol";
contract MiningPool is AccessControl, ReentrancyGuard {
    uint256 public constant MAX_PRS_SUPPLY = 1000000;  // Maximum PRS supply
    uint256 public constant INITIAL_DIFFICULTY_INDEX = 1000; // Initial difficulty index
    
    uint256 public mint_tx; // Number of mint transactions
    uint256 public revoke_tx; // Number of revoke transactions
    uint256 public totalNFTTransactions; // Total NFT transactions (mint + revoke)
    uint256 public totalMinedPRS; // Total mined PRS
    uint256 public difficultyIndex = INITIAL_DIFFICULTY_INDEX; // Difficulty index
    uint256 public prsFactor; // Fraction of transaction fee converted to PRS tokens
    mapping(uint256 => uint256) public tokenPrices; // Tracking token prices per transaction

    bytes32 public constant WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE");

    event MiningDetailsUpdated(uint256 minedPRS, uint256 transactionCount);

    constructor(uint256 _initialPrsFactor) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); // Setting the deployer as the default admin
        prsFactor = _initialPrsFactor;
        mint_tx = 0;
        revoke_tx = 0;
        totalNFTTransactions = 0;
        totalMinedPRS = 0;
    }

    modifier onlyWhitelisted() {
        require(hasRole(WHITELISTED_ROLE, msg.sender), "Caller is not whitelisted");
        _;
    }

    function recordNFTTransaction(uint256 transactionFee) external onlyWhitelisted nonReentrant {
        totalNFTTransactions = mint_tx + revoke_tx;
        uint256 prsFract = transactionFee * prsFactor / 100;
        uint256 minedPRS = MAX_PRS_SUPPLY / (difficultyIndex * totalNFTTransactions);
        totalMinedPRS += minedPRS;

        require(totalMinedPRS <= MAX_PRS_SUPPLY/2, "Exceeds maximum PRS supply");

        tokenPrices[totalNFTTransactions] = prsFract / minedPRS;
        emit MiningDetailsUpdated(minedPRS, totalNFTTransactions);
    }

    function recordMintTx() external onlyWhitelisted nonReentrant {
        mint_tx++;
    }

    function recordRevokeTx() external onlyWhitelisted nonReentrant {
        revoke_tx++;
    }

    function adjustDifficultyIndex(uint256 newDifficultyIndex) public onlyRole(DEFAULT_ADMIN_ROLE) {
        difficultyIndex = newDifficultyIndex;
    }

    function calculateAverageTokenValue() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 1; i <= totalNFTTransactions; i++) {
            sum += tokenPrices[i];
        }
        return sum / totalNFTTransactions;
    }

    function calculateTokenFaceValue(uint256 supplyDemandIndex) public view returns (uint256) {
        return calculateAverageTokenValue() * supplyDemandIndex;
    }

    function updatePrsFactor(uint256 newPrsFactor) public onlyRole(DEFAULT_ADMIN_ROLE) {
        prsFactor = newPrsFactor;
    }

    function getTotalMinedPRS() external view returns (uint256) {
        return totalMinedPRS;
    }

    function addWhitelisted(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(WHITELISTED_ROLE, account);
    }

    function revokeWhitelisted(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(WHITELISTED_ROLE, account);
    }
}