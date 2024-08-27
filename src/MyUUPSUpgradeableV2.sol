// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MyUUPSUpgradeable.sol";

contract MyUUPSUpgradeableV2 is MyUUPSUpgradeable {
    // slot zero: value(V1)
    uint256 public value2;

    // New initialize function
    function initializeV2(uint256 _initialValue) public reinitializer(2) {
        value2 = _initialValue;
    }

    function setValue2(uint256 _value) public onlyOwner {
        value2 = _value;
    }

    function returnValue2() public view returns (uint256) {
        return value2;
    }

    // 업그레이드된 버전 함수
    function version() public pure virtual override returns (string memory) {
        return "V2";
    }
}
