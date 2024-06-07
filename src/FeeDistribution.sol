// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Ownable.sol";
import "./IERC20.sol";
import "./Address.sol";
import "./IFeeDistribution.sol";

interface IMiningPool {
    function recordNFTTransaction(uint256 transactionFee) external;
}

contract FeeDistribution is Ownable, IFeeDistribution {
    using Address for address payable;

    struct Recipient {
        address wallet;
        uint256 percentage; // Percentage in basis points (100 bps = 1%)
    }

    Recipient public miningPoolRecipient;
    Recipient public treasuryRecipient;

    event FeesReceived(address indexed from, uint256 amount);
    event FeesDistributed(address indexed recipient, uint256 amount);

    constructor(address initialOwner, address _miningPool, uint256 miningPoolPercentage, address _treasury, uint256 treasuryPercentage) Ownable(initialOwner) {
        require(_miningPool != address(0), "Invalid mining pool address");
        require(_treasury != address(0), "Invalid treasury address");
        require(miningPoolPercentage + treasuryPercentage == 10000, "Total percentage must be 10000 basis points");

        miningPoolRecipient = Recipient({ wallet: _miningPool, percentage: miningPoolPercentage });
        treasuryRecipient = Recipient({ wallet: _treasury, percentage: treasuryPercentage });
    }

    function distributeERC20Fees(IERC20 token, uint256 amount) external override {
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Insufficient balance to distribute");

        uint256 totalToMiningPool = distributeToRecipient(token, miningPoolRecipient, amount);
        distributeToRecipient(token, treasuryRecipient, amount);

        // Record the NFT transaction in the mining pool
        if (totalToMiningPool > 0) {
            IMiningPool(miningPoolRecipient.wallet).recordNFTTransaction(totalToMiningPool);
        }
    }

    function distributeToRecipient(IERC20 token, Recipient memory recipient, uint256 amount) internal returns (uint256) {
        uint256 recipientAmount = (amount * recipient.percentage) / 10000;
        require(token.transfer(recipient.wallet, recipientAmount), "ERC20 transfer failed");
        emit FeesDistributed(recipient.wallet, recipientAmount);
        return recipientAmount;
    }

    function updateMiningPool(address _miningPool, uint256 miningPoolPercentage) external onlyOwner {
        require(_miningPool != address(0), "Invalid mining pool address");
        miningPoolRecipient = Recipient({ wallet: _miningPool, percentage: miningPoolPercentage });
        validateTotalPercentage();
    }

    function updateTreasury(address _treasury, uint256 treasuryPercentage) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        treasuryRecipient = Recipient({ wallet: _treasury, percentage: treasuryPercentage });
        validateTotalPercentage();
    }

    function validateTotalPercentage() internal view {
        uint256 totalPercentage = miningPoolRecipient.percentage + treasuryRecipient.percentage;
        require(totalPercentage == 10000, "Total percentage must be 10000 basis points");
    }
}
