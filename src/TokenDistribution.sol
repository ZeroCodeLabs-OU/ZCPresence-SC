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

    constructor(address _token, address _usdt, address _priceFeed, address initialOwner)
        Ownable(initialOwner)  
    {
        require(_token != address(0) && _usdt != address(0) && _priceFeed != address(0), "Invalid address");

        token = IERC20(_token);
        usdt = IERC20(_usdt);
        priceFeed = AggregatorV3Interface(_priceFeed);
        tokenPriceUSD = 1 * 10**18; // default price $1 per token, can be updated
    }


    function depositTokens(uint256 amount) public onlyOwner {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    function setTokenPriceUSD(uint256 price) public onlyOwner {
        tokenPriceUSD = price;
    }

    function buyTokens(uint256 usdtAmount) public nonReentrant {
        (,int256 price,,,) = priceFeed.latestRoundData();
        uint256 usdToTokenAmount = usdtAmount * uint256(price) / 10**8; // Convert USDT amount to equivalent USD amount
        uint256 tokensToBuy = usdToTokenAmount * 10**18 / tokenPriceUSD; // Determine number of tokens to buy based on USD price

        require(usdt.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        require(token.transfer(msg.sender, tokensToBuy), "Token transfer failed");
    }

    function withdrawUSDT(uint256 amount) public onlyOwner {
        require(usdt.transfer(msg.sender, amount), "Withdrawal failed");
    }
}
