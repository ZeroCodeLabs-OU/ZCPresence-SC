// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Ownable.sol";
import "./IERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./SafeERC20.sol";
interface IMiningPool {
    function calculateAverageTokenValue() external view returns (uint256);
    function getTotalMinedPRS() external view returns (uint256);
}

contract TokenDistribution is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;
    IERC20 public usdt;
    AggregatorV3Interface public priceFeed;
    IMiningPool public miningPool;

    uint256 public tokenPriceUSD;

    // Price range limits
    uint256 public minUsdtPrice = 98000000; // 0.98 USDT per USD, scaled by 1e8
    uint256 public maxUsdtPrice = 102000000; // 1.02 USDT per USD, scaled by 1e8

    // Events
    event TokensPurchased(address indexed buyer, uint256 usdtSpent, uint256 tokensBought);
    event TokensDeposited(uint256 amount);
    event TokenPriceUpdated(uint256 newPrice);
    event USDTWithdrawn(uint256 amount);
    event OraclePriceData(int256 price);
    event PriceOutOfRange(int256 reportedPrice);

    constructor(
        address _token,
        address _usdt,
        address _priceFeed,
        address _miningPool,
        address initialOwner
    )
        Ownable(initialOwner)
    {
        require(_token != address(0), "Token address cannot be zero");
        require(_usdt != address(0), "USDT address cannot be zero");
        require(_priceFeed != address(0), "Price feed address cannot be zero");
        require(_miningPool != address(0), "Mining pool address cannot be zero");

        token = IERC20(_token);
        usdt = IERC20(_usdt);
        priceFeed = AggregatorV3Interface(_priceFeed);
        miningPool = IMiningPool(_miningPool);
        tokenPriceUSD = 1 * 10**18;
    }

    function depositTokens(uint256 amount) public onlyOwner {
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit TokensDeposited(amount);
    }

    function setTokenPriceUSD(uint256 price) public onlyOwner {
        require(price > 0, "Price must be greater than zero");
        tokenPriceUSD = price;
        emit TokenPriceUpdated(price);
    }

    function getTokenPrice() public view returns (uint256) {
        return miningPool.calculateAverageTokenValue();
    }

    function getAvailableTokens() public view returns (uint256) {
        return miningPool.getTotalMinedPRS();
    }

    function buyTokens(uint256 usdtAmount) public {
        require(usdtAmount > 0, "USDT amount must be greater than zero");
        uint256 availableTokens = getAvailableTokens();
        require(availableTokens > 0, "No tokens available for sale");

        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data");
        require(uint256(price) >= minUsdtPrice && uint256(price) <= maxUsdtPrice, "USDT price out of range");
        emit OraclePriceData(price);

        uint256 usdAmount = (usdtAmount * uint256(price)) / 1e8;
        uint256 tokenAveragePrice = getTokenPrice();
        uint256 tokensToBuy = (usdAmount * 10**18) / tokenAveragePrice;

        require(tokensToBuy <= availableTokens, "Not enough tokens available for sale");
        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);
        token.safeTransfer(msg.sender, tokensToBuy);

        emit TokensPurchased(msg.sender, usdtAmount, tokensToBuy);
    }

    function withdrawUSDT(uint256 amount) public onlyOwner {
        usdt.safeTransfer(msg.sender, amount);
        emit USDTWithdrawn(amount);
    }
}