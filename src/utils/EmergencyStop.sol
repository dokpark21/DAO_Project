// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract EmergencyStop {
    bool public stopped;

    modifier notEmergency() {
        require(!stopped, "Contract is stopped");
        _;
    }

    modifier onlyEmergency() {
        require(stopped, "Not Emergency");
        _;
    }

    function stop() public virtual;

    function start() public virtual;
}
