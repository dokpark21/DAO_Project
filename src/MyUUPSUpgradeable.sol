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

    event UpgradeAuthorized(address indexed newImplementation);

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

    function multicall(
        bytes[] calldata data
    ) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );
            require(success, "Multicall: delegatecall failed");
            results[i] = result;
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {
        // 새로운 구현 주소의 유효성을 확인
        require(
            newImplementation != address(0),
            "New implementation address cannot be zero"
        );
        require(
            isContract(newImplementation),
            "New implementation must be a contract"
        );

        // 업그레이드 승인 이벤트 로그 기록
        emit UpgradeAuthorized(newImplementation);
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
