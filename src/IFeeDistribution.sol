// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "./IERC20.sol";
interface IFeeDistribution {
    function distributeERC20Fees(IERC20 token, uint256 amount) external;
}
