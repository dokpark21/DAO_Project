// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";

contract MyUUPSUpgradeable is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    // 상태 변수 및 로직 정의
    uint256 public value;

    function initialize(uint256 _initialValue) public initializer {
        value = _initialValue;

        __Ownable_init(); // Ownable 초기화
    }

    function setValue(uint256 _value) public onlyOwner {
        value = _value;
    }

    function returnValue() public view returns (address) {
        return value;
    }

    function version() public pure virtual override returns (string memory) {
        return "V1";
    }

    // UUPS 업그레이드를 위한 권한 검사 함수
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
