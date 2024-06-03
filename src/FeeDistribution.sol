// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Ownable.sol";
import "./IERC20.sol";
import "./Address.sol";
import "./IFeeDistribution.sol";

contract FeeDistribution is Ownable, IFeeDistribution {
    using Address for address payable;

    struct Recipient {
        address wallet;
        uint256 percentage; // Percentage in basis points (100 bps = 1%)
    }

    Recipient[] public recipients;
    uint256 public totalPercentage; // Must always be 10000 basis points

    event FeesReceived(address indexed from, uint256 amount);
    event FeesDistributed(address indexed recipient, uint256 amount);

    constructor(address initialOwner, Recipient[] memory _recipients) Ownable(initialOwner) {
        require(_recipients.length > 0, "No recipients provided");

        uint256 total = 0;
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i].wallet != address(0), "Invalid wallet address");
            require(_recipients[i].percentage > 0, "Percentage must be greater than 0");
            recipients.push(_recipients[i]);
            total += _recipients[i].percentage;
        }
        require(total == 10000, "Total percentage must be 10000 basis points");

        totalPercentage = total;
    }

    function distributeERC20Fees(IERC20 token, uint256 amount) external override {
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Insufficient balance to distribute");

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 recipientAmount = (amount * recipients[i].percentage) / 10000;
            require(token.transfer(recipients[i].wallet, recipientAmount), "ERC20 transfer failed");
            emit FeesDistributed(recipients[i].wallet, recipientAmount);
        }
    }

    function updateRecipients(Recipient[] memory _recipients) external onlyOwner {
        delete recipients;
        uint256 total = 0;
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i].wallet != address(0), "Invalid wallet address");
            require(_recipients[i].percentage > 0, "Percentage must be greater than 0");
            recipients.push(_recipients[i]);
            total += _recipients[i].percentage;
        }
        require(total == 10000, "Total percentage must be 10000 basis points");
        totalPercentage = total;
    }
}
