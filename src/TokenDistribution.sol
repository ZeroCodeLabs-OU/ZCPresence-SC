// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./IERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract TokenDistribution is Ownable, ReentrancyGuard {
    IERC20 public token;
    IERC20 public usdt;
    AggregatorV3Interface public priceFeed;

    uint256 public tokenPriceUSD;  // Price per token in USD with 18 decimals

    // Events
    event TokensPurchased(address buyer, uint256 usdtSpent, uint256 tokensBought);
    event TokensDeposited(uint256 amount);
    event TokensPriceUpdated(uint256 newPrice);
    event USDTWithdrawn(uint256 amount);

    constructor(address _token, address _usdt, address _priceFeed, address initialOwner)
        Ownable(initialOwner)  
    {
        require(_token != address(0), "Token address cannot be zero");
        require(_usdt != address(0), "USDT address cannot be zero");
        require(_priceFeed != address(0), "Price feed address cannot be zero");

        token = IERC20(_token);
        usdt = IERC20(_usdt);
        priceFeed = AggregatorV3Interface(_priceFeed);
        tokenPriceUSD = 1 * 10**18; // Default price $1 per token
    }

    function depositTokens(uint256 amount) public onlyOwner {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit TokensDeposited(amount);
    }

    function setTokenPriceUSD(uint256 price) public onlyOwner {
        require(price > 0, "Price must be greater than zero");
        tokenPriceUSD = price;
        emit TokensPriceUpdated(price);
    }

    function buyTokens(uint256 usdtAmount) public nonReentrant {
        require(usdtAmount > 0, "USDT amount must be greater than zero");
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data");

        uint256 usdToTokenAmount = usdtAmount * uint256(price) / 10**8; // Convert USDT to equivalent USD
        uint256 tokensToBuy = usdToTokenAmount * 10**18 / tokenPriceUSD; // Determine tokens to buy

        require(usdt.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        require(token.transfer(msg.sender, tokensToBuy), "Token transfer failed");

        emit TokensPurchased(msg.sender, usdtAmount, tokensToBuy);
    }

    function withdrawUSDT(uint256 amount) public onlyOwner {
        require(usdt.transfer(msg.sender, amount), "Withdrawal failed");
        emit USDTWithdrawn(amount);
    }
}
