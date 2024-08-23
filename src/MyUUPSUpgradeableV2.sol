// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyUUPSUpgradeable.sol";

contract MyUUPSUpgradeableV2 is MyUUPSUpgradeable {
    // 상태 변수 및 로직 정의
    uint256 public value2;

    function initializeV2(uint256 _initialValue) public initializer {
        value2 = _initialValue;
    }

    function setValue2(uint256 _value) public onlyOwner {
        value2 = _value;
    }

    function returnValue2() public view returns (uint256) {
        return value2;
    }

    function version() public pure virtual override returns (string memory) {
        return "V2";
    }
}
