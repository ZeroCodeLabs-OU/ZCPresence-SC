// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library TokenUtils {
    struct TokenInfo {
        IERC20 payToken;
        uint256 staticCost;
        bool useOracle;
        address priceFeedAddress;
    }

    function calculatePrice(TokenInfo memory self, uint256 amount) public view returns (uint256 totalCost) {
        if (self.useOracle) {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(self.priceFeedAddress);
            (, int256 latestPrice, , , ) = priceFeed.latestRoundData();
            require(latestPrice > 0, "Invalid price data");
            uint256 decimals = priceFeed.decimals();
            totalCost = (self.staticCost * 10 ** decimals) / uint256(latestPrice);
        } else {
            totalCost = self.staticCost;
        }
        totalCost *= amount;
        return totalCost;
    }
}
