// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TokenDistributor is ReentrancyGuard, Pausable {
    IERC20 public immutable usdc;
    address public owner;
    address public admin;
    
    // Constants
    uint256 public constant MAX_BATCH_SIZE = 200;
    
    // State variables
    uint256 public totalPendingWithdrawals;
    
    // Mapping to store allowed withdrawal amounts for each address
    mapping(address => uint256) public allowedWithdrawals;
    
    // Events
    event WithdrawalAllowanceSet(address indexed recipient, uint256 amount);
    event TokensWithdrawn(address indexed recipient, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event OwnerWithdrawal(address indexed recipient, uint256 amount);
    
    error InvalidAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error Unauthorized();
    error BatchSizeExceeded();
    error ArrayLengthMismatch();
    error NoWithdrawalAvailable();
    error TransferFailed();
    error WithdrawalWouldAffectPending();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin && msg.sender != owner) revert Unauthorized();
        _;
    }
    
    constructor(address _usdcAddress, address _owner, address _admin) {
        if (_usdcAddress == address(0) || _owner == address(0) || _admin == address(0)) revert InvalidAddress();
        
        usdc = IERC20(_usdcAddress);
        owner = _owner;
        admin = _admin;
        
        emit OwnerChanged(address(0), _owner);
        emit AdminChanged(address(0), _admin);
    }
    
    function setOwner(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert InvalidAddress();
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnerChanged(oldOwner, _newOwner);
    }

    function setAdmin(address _newAdmin) external onlyOwner {
        if (_newAdmin == address(0)) revert InvalidAddress();
        address oldAdmin = admin;
        admin = _newAdmin;
        emit AdminChanged(oldAdmin, _newAdmin);
    }

    /**
     * @dev Allows owner to withdraw tokens
     * @param amount Amount of tokens to withdraw
     * @param recipient Address to receive the tokens
     */
    function ownerWithdraw(uint256 amount, address recipient) external nonReentrant onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        
        uint256 contractBalance = usdc.balanceOf(address(this));
        if (contractBalance < amount) revert InsufficientBalance();
        
        bool success = usdc.transfer(recipient, amount);
        if (!success) revert TransferFailed();
        
        emit OwnerWithdrawal(recipient, amount);
    }
    
    /**
     * @dev Allows admin to set multiple withdrawal allowances at once
     * @param recipients Array of addresses that can withdraw
     * @param amounts Array of amounts each address can withdraw
     */
    function setBulkWithdrawalAllowances(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external whenNotPaused onlyAdmin {
        uint256 length = recipients.length;
        if (length > MAX_BATCH_SIZE) revert BatchSizeExceeded();
        if (length != amounts.length) revert ArrayLengthMismatch();
        
        uint256 newTotalPending = totalPendingWithdrawals;
        
        for (uint256 i = 0; i < length;) {
            if (recipients[i] == address(0)) revert InvalidAddress();
            if (amounts[i] == 0) revert InvalidAmount();
            
            // Subtract previous allowance from total pending if it exists
            uint256 previousAllowance = allowedWithdrawals[recipients[i]];
            if (previousAllowance > 0) {
                newTotalPending -= previousAllowance;
            }
            
            // Add new allowance
            newTotalPending += amounts[i];
            allowedWithdrawals[recipients[i]] = amounts[i];
            
            emit WithdrawalAllowanceSet(recipients[i], amounts[i]);
            
            unchecked {
                ++i;
            }
        }
        
        // Update total pending withdrawals
        totalPendingWithdrawals = newTotalPending;
        
        // Verify contract has sufficient balance for all allowances
        if (usdc.balanceOf(address(this)) < newTotalPending) revert InsufficientBalance();
    }
    
    /**
     * @dev Allows users to withdraw their allocated tokens
     * @param withdrawalAddress Address where tokens should be sent
     */
    function withdrawTokens(address withdrawalAddress) external nonReentrant whenNotPaused onlyAdmin {
        if (withdrawalAddress == address(0)) revert InvalidAddress();
        
        uint256 amount = allowedWithdrawals[withdrawalAddress];
        if (amount == 0) revert NoWithdrawalAvailable();
        
        // Reset withdrawal allowance and update total pending
        allowedWithdrawals[withdrawalAddress] = 0;
        totalPendingWithdrawals -= amount;
        
        // Transfer tokens
        bool success = usdc.transfer(withdrawalAddress, amount);
        if (!success) revert TransferFailed();
        
        emit TokensWithdrawn(withdrawalAddress, amount);
    }

    // Emergency functions
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }

    // View functions
    function getContractBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    function getWithdrawalAmount(address account) external view returns (uint256) {
        return allowedWithdrawals[account];
    }
}