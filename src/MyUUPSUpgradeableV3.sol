// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MyUUPSUpgradeableV2.sol"; // V2를 상속받아서 V1의 기능도 상속됨

contract MyUUPSUpgradeableV3 is MyUUPSUpgradeableV2 {
    // 새로운 기능과 상태 변수 추가
    uint256 public value3;

    function initializeV3(uint256 _initialValue) public reinitializer(3) {
        value3 = _initialValue;
    }

    function setValue3(uint256 _value) public onlyOwner {
        value3 = _value;
    }

    function returnValue3() public view returns (uint256) {
        return value3;
    }

    function version() public pure virtual override returns (string memory) {
        return "V3";
    }
}
