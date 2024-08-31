// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DAOUpgradeable.sol";

contract DAOUpgradeableV2 is DAOUpgradeable {
    function version() public pure override returns (string memory) {
        return "V2";
    }
}
