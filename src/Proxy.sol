// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "./ERC1967Upgrade.sol";

// UUPS Pattern
contract DAOProxy is ERC1967Upgrade, Proxy {
    constructor(address _logic, bytes memory _data) payable {
        assert(
            _IMPLEMENTATION_SLOT ==
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );
        // 초기 구현체 설정 및 초기화 함수 호출
        _upgradeToAndCall(_logic, _data, false);
    }

    function _implementation()
        internal
        view
        virtual
        override
        returns (address impl)
    {
        return _getImplementation();
    }
    // return slot
    function proxiableUUID() external view returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    // 멀티콜 기능을 위한 별도 함수 추가
    function multicall(
        bytes[] calldata data
    ) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = _implementation()
                .delegatecall(data[i]);
            require(success, "Multicall: delegatecall failed");
            results[i] = result;
        }
    }

    fallback() external payable {
        _fallback();
    }
}
