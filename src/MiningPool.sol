// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./AccessControl.sol";
import "./ReentrancyGuard.sol";
contract MiningPool is AccessControl, ReentrancyGuard {
    uint256 public constant MAX_PRS_SUPPLY = 1000000;
    uint256 public constant INITIAL_DIFFICULTY_INDEX = 1000;
    
    uint256 public mint_tx;
    uint256 public revoke_tx;
    uint256 public totalNFTTransactions;
    uint256 public totalMinedPRS;
    uint256 public difficultyIndex = INITIAL_DIFFICULTY_INDEX;
    uint256 public prsFactor;
    mapping(uint256 => uint256) public tokenPrices;

    bytes32 public constant WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE");

    event MiningDetailsUpdated(uint256 minedPRS, uint256 transactionCount);

    constructor(uint256 _initialPrsFactor) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        prsFactor = _initialPrsFactor;
        mint_tx = 0;
        revoke_tx = 0;
        totalNFTTransactions = 0;
        totalMinedPRS = 0;
    }

    function recordNFTTransaction(uint256 transactionFee) external onlyRole(WHITELISTED_ROLE) nonReentrant {
        totalNFTTransactions = mint_tx + revoke_tx;
        uint256 prsFract = transactionFee * prsFactor / 100;
        uint256 minedPRS = MAX_PRS_SUPPLY / (difficultyIndex * totalNFTTransactions);
        totalMinedPRS += minedPRS;

        require(totalMinedPRS <= MAX_PRS_SUPPLY / 2, "Exceeds maximum PRS supply");

        tokenPrices[totalNFTTransactions] = prsFract / minedPRS;
        emit MiningDetailsUpdated(minedPRS, totalNFTTransactions);
    }

    function recordMintTx() external onlyRole(WHITELISTED_ROLE) nonReentrant {
        mint_tx++;
    }

    function recordRevokeTx() external onlyRole(WHITELISTED_ROLE) nonReentrant {
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
