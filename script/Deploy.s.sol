// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/governance/DaoGovernor.sol";
import "../src/governance/GovernanceToken.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/UUPSProxy/DAOProxy.sol";
import "../src/UUPSProxy/DAOUpgradeable.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract Deploy is Script {
    GovernanceToken governanceToken;
    TimelockController timelock;
    DaoGovernor daoGovernor;
    DAOUpgradeable logic;
    DAOProxy proxy;
    address proxyAdmin;

    function run() external {
        vm.startBroadcast();

        address owner = msg.sender;

        governanceToken = new GovernanceToken(owner);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = owner;
        executors[0] = owner;
        timelock = new TimelockController(1, proposers, executors, owner);

        daoGovernor = new DaoGovernor(
            IVotes(address(governanceToken)),
            timelock,
            1 days,
            5 days,
            100 * 10 ** 18,
            50
        );

        logic = new DAOUpgradeable();

        proxyAdmin = address(daoGovernor);

        proxy = new DAOProxy(
            address(daoGovernor),
            address(logic),
            abi.encodeWithSelector(DAOUpgradeable.initialize.selector, owner)
        );

        bytes memory data = abi.encodeWithSelector(
            DAOUpgradeable.changeOwner.selector,
            address(daoGovernor)
        );

        (bool success, ) = address(proxy).call(data);
        require(success, "changeOwner failed");

        console.log("GovernanceToken deployed at:", address(governanceToken));
        console.log("TimelockController deployed at:", address(timelock));
        console.log("DAOUpgradeable (logic) deployed at:", address(logic));
        console.log("DAOProxy deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}
