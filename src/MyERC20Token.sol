// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./ERC20Pausable.sol";
import "./AccessControl.sol";
import "./ERC20Permit.sol";

contract MyERC20Token  is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ERC20Permit {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant AIRDROPPER_ROLE = keccak256("AIRDROPPER_ROLE");

    uint256 private _cap;
    bool private _isSupplyUnlimited;
    event AirdropPerformed(address indexed by, uint256 totalAmount);

   constructor(
        string memory name, 
        string memory symbol, 
        address defaultAdmin, 
        address pauser, 
        address minter,
        address airdropper,
        uint256 capacity,
        bool UnlimitedSupply
    )
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(AIRDROPPER_ROLE, airdropper);
        _cap = capacity;
        _isSupplyUnlimited = UnlimitedSupply;
    }

    function airdrop(address[] memory recipients, uint256[] memory amounts) public onlyRole(AIRDROPPER_ROLE) {
        require(recipients.length == amounts.length, "MyToken: recipients and amounts length mismatch");

        uint256 totalAirdropAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAirdropAmount += amounts[i];
        }

        if (!_isSupplyUnlimited) {
            require(totalSupply() + totalAirdropAmount <= _cap, "MyToken: cap exceeded");
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }

        emit AirdropPerformed(msg.sender, totalAirdropAmount);
    }
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        if (!_isSupplyUnlimited) {
            require(totalSupply() + amount <= _cap, "MyToken: cap exceeded");
        }
        _mint(to, amount);
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function isSupplyUnlimited() public view returns (bool) {
        return _isSupplyUnlimited;
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}