// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract MultisigTimelock is IERC721Receiver, IERC1155Receiver {
    bytes32 private constant MODULE_TYPE = bytes32("MultiSig");
    uint256 private constant VERSION = 1;

    address[] public owners;
    uint256 public numConfirmationsRequired;
    uint256 public timelockPeriod; // in seconds

    //Events
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txIndex, address indexed owner);
    event Confirm(uint256 indexed txIndex, address indexed owner);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 confirmationCount;
        bool executed;
        uint256 timestamp;
    }

    // mapping from tx index => owner => bool
    Transaction[] public transactions;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    mapping(address => uint256) public lastConfirmationTime;
    mapping(uint256 => uint256) public transactionExecutableTime;

    // Constructor
    constructor(
        address[] memory _owners,
        uint256 _numConfirmationsRequired,
        uint256 _timelockPeriod
    ) {
        require(_owners.length >= 3, "At least three owners required");
        require(
            _numConfirmationsRequired >= (_owners.length / 2) + 1 &&
                _numConfirmationsRequired <= _owners.length,
            "Invalid number of required confirmations"
        );

        require(_timelockPeriod >= 0, "Invalid timelock period"); //24hrs

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner address");
            require(!isOwner[owner], "Duplicate owner address");
            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
        timelockPeriod = _timelockPeriod;
    }

    // Modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only owners can call this function");
        _;
    }

    modifier txExists(uint256 transactionId) {
        require(transactionId < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 transactionId) {
        require(
            !isConfirmed[transactionId][msg.sender],
            "tx already confirmed"
        );
        _;
    }

    modifier timeLockExpired(uint256 transactionId) {
        require(
            block.timestamp >= transactionExecutableTime[transactionId] &&
                transactionExecutableTime[transactionId] != 0,
            "Timelock period has not expired"
        );

        _;
    }

    // Functions

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getRequiredConfirmations() external view returns (uint256) {
        return numConfirmationsRequired;
    }

    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata _data
    ) public onlyOwner returns (uint256) {
        uint256 transactionId = transactions.length;
        transactions.push(
            Transaction({
                to: to,
                value: value,
                data: _data,
                executed: false,
                timestamp: block.timestamp,
                confirmationCount: 1
            })
        );

        isConfirmed[transactionId][msg.sender] = true;
        lastConfirmationTime[msg.sender] = block.timestamp;
        emit Submit(transactionId, msg.sender);
        return transactionId;
    }

    function confirmTransaction(
        uint256 transactionId
    )
        external
        onlyOwner
        txExists(transactionId)
        notConfirmed(transactionId)
        notExecuted(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];
        transaction.confirmationCount += 1;
        isConfirmed[transactionId][msg.sender] = true;
        lastConfirmationTime[msg.sender] = block.timestamp;

        if (
            transaction.confirmationCount >= numConfirmationsRequired &&
            transactionExecutableTime[transactionId] == 0
        ) {
            transactionExecutableTime[transactionId] =
                block.timestamp +
                timelockPeriod;
        }

        emit Confirm(transactionId, msg.sender);
    }

    function revokeConfirmation(
        uint256 transactionId
    ) external txExists(transactionId) notExecuted(transactionId) {
        Transaction storage transaction = transactions[transactionId];

        require(isOwner[msg.sender], "Only owners can call this function");

        require(isConfirmed[transactionId][msg.sender], "tx not confirmed");

        transaction.confirmationCount -= 1;
        isConfirmed[transactionId][msg.sender] = false;

        if (
            transaction.confirmationCount < numConfirmationsRequired &&
            transactionExecutableTime[transactionId] != 0
        ) {
            transactionExecutableTime[transactionId] = 0;
        }
    }

    function executeTransaction(
        uint256 transactionId
    )
        public
        onlyOwner
        txExists(transactionId)
        timeLockExpired(transactionId)
        notExecuted(transactionId)
    {
        require(
            getConfirmationCount(transactionId) >= numConfirmationsRequired,
            "Not enough confirmations"
        );

        Transaction storage transaction = transactions[transactionId];

        // address payable to = payable(address(this));
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        ); //to.call{value: address(this).balance}("");
        require(success, "Transaction execution failed");

        transaction.executed = true;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(
        uint256 transactionId
    ) external view returns (Transaction memory) {
        return transactions[transactionId];
    }

    function getConfirmationCount(
        uint256 transactionId
    ) public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (isConfirmed[transactionId][owners[i]]) {
                count += 1;
            }
        }
        return count;
    }

    function getWalletBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTimelockPeriod() external view returns (uint256) {
        return timelockPeriod;
    }

    function getBlockTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    /// @dev Returns the module type of the contract.
    function contractType() external pure virtual returns (bytes32) {
        return MODULE_TYPE;
    }

    /// @dev Returns the version of the contract.
    function contractVersion() external pure virtual returns (uint8) {
        return uint8(VERSION);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /*///////////////////////////////////////////////////////////////
                        ERC 165 / 721 / 1155 logic
    //////////////////////////////////////////////////////////////*/
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        transactions.push(
            Transaction({
                to: operator,
                value: tokenId,
                data: data,
                executed: false,
                timestamp: block.timestamp,
                confirmationCount: 0
            })
        );

        isConfirmed[transactions.length][from] = true;
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address, // operator,
        address, // from,
        uint256, //id,
        uint256, // value,
        bytes calldata // data
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address, // operator,
        address, // from,
        uint256[] calldata, // ids,
        uint256[] calldata, // values,
        bytes calldata // data
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId;
    }
}
