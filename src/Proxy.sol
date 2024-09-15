// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Proxy {
    address public implementation;
    address public admin;

    event ProxyUpdated(address indexed _old, address indexed _new);
    event OwnerUpdated(address indexed _old, address indexed _new);

    constructor() {
        admin = address(0);
        implementation = address(0);
    }

    function upgrade(address _newImplementation) external {
        require(msg.sender == admin, "Only admin can upgrade");
        address old = implementation;

        implementation = _newImplementation;
        emit ProxyUpdated(old, _newImplementation);
    }

    function changeOwner(address newOwner) external {
        require(admin == address(0) || msg.sender == admin, "Only admin can upgrade");
        admin = newOwner;
        emit OwnerUpdated(msg.sender, newOwner);
    }

    fallback() external payable {
        (bool success,) = implementation.delegatecall(msg.data);
        require(success, "Delegatecall failed");
    }

    receive() external payable {}
}
