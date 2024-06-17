// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


interface IMiningPool {
    function recordMintTx() external;
    function recordRevokeTx() external;
}
