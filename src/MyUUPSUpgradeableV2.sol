// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MyUUPSUpgradeable.sol";

contract MyUUPSUpgradeableV2 is DAOUpgradeable {
    // slot zero: value(V1)
    uint256 public value2;

    // New initialize function
    function initializeV2(uint256 _initialValue) public reinitializer(2) {
        value2 = _initialValue;
        emergencyStopped = false;
    }

    // 업그레이드된 버전 함수
    function version() public pure virtual override returns (string memory) {
        return "V2";
    }
}
