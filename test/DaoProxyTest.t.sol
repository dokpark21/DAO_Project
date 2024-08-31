// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/UUPSProxy/DAOProxy.sol";
import "../src/UUPSProxy/DAOUpgradeable.sol";
import "../src/UUPSProxy/DAOUpgradeableV2.sol";
import {console} from "forge-std/console.sol";

contract DAOProxyTest is Test {
    DAOProxy public proxy;
    DAOUpgradeable public logic;
    DAOUpgradeable public proxyAsLogic;

    address public proxyAdmin;
    address public user;
    address public user2;

    function setUp() public {
        proxyAdmin = address(this);
        user = address(0x123);
        user2 = address(0x456);

        payable(user).transfer(1 ether);

        logic = new DAOUpgradeable();

        proxy = new DAOProxy(
            address(this),
            address(logic),
            abi.encodeWithSelector(
                DAOUpgradeable.initialize.selector,
                proxyAdmin
            )
        );

        // 프록시 주소를 DAOUpgradeable 인터페이스로 캐스팅합니다.
        proxyAsLogic = DAOUpgradeable(address(proxy));
    }

    function testSingleCallThroughProxy() public {
        vm.startPrank(user);

        bytes memory depositCalldata = abi.encodeWithSelector(
            proxyAsLogic.deposit.selector
        );
        (bool success, ) = address(proxy).call{value: 1 ether}(depositCalldata);
        assertTrue(success, "Deposit failed through proxy");
        assertEq(proxyAsLogic.totalDeposits(), 1 ether);
        assertEq(proxyAsLogic.balanceOf(user), 1 ether);

        bytes memory withdrawCalldata = abi.encodeWithSelector(
            proxyAsLogic.withdraw.selector,
            0.5 ether
        );
        (success, ) = address(proxy).call(withdrawCalldata);
        assertTrue(success, "Withdraw failed through proxy");
        assertEq(proxyAsLogic.totalDeposits(), 0.5 ether);
        assertEq(proxyAsLogic.balanceOf(user), 0.5 ether);

        vm.stopPrank();
    }

    function testMultiCallThroughProxy() public {
        // 테스트 2: 다중 msg.data를 사용하여 multicall을 호출합니다.
        vm.startPrank(user);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(proxyAsLogic.deposit.selector);
        data[1] = abi.encodeWithSelector(
            proxyAsLogic.withdraw.selector,
            0.5 ether
        );

        // 프록시를 통해 멀티콜을 실행합니다.
        (bool success, bytes memory result) = address(proxy).call{
            value: 1 ether
        }(abi.encodeWithSelector(proxy.multicall.selector, data));

        // 멀티콜 결과를 검증합니다.
        assertTrue(success, "Multicall failed");
        bytes[] memory results = abi.decode(result, (bytes[]));
        assertEq(results.length, 2, "Incorrect number of results");
        assertEq(proxyAsLogic.totalDeposits(), 0.5 ether);
        assertEq(proxyAsLogic.balanceOf(user), 0.5 ether);

        vm.stopPrank();
    }

    function testDoubleDepositFail() public {
        // 테스트 3: 리엔트런시 공격을 시도합니다.
        vm.startPrank(user);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(proxyAsLogic.deposit.selector);
        data[1] = abi.encodeWithSelector(proxyAsLogic.deposit.selector);

        // 프록시를 통해 멀티콜을 실행합니다.
        vm.expectRevert();
        (bool success, ) = address(proxy).call{value: 1 ether}(
            abi.encodeWithSelector(proxy.multicall.selector, data)
        );
        vm.stopPrank();
    }

    function testInsufficientBalanceFail() public {
        // 테스트 4: 충분한 예치금이 없는 경우 인출을 시도합니다.
        vm.startPrank(user);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            proxyAsLogic.withdraw.selector,
            1 ether
        );

        // 프록시를 통해 멀티콜을 실행합니다.
        vm.expectRevert();
        (bool success, ) = address(proxy).call(data[0]);
        vm.stopPrank();
    }

    function testEmergencyFail() public {
        vm.startPrank(proxyAdmin);

        bytes memory stopEmergencyCalldata = abi.encodeWithSelector(
            proxyAsLogic.stop.selector
        );

        (bool success, ) = address(proxy).call(stopEmergencyCalldata);

        vm.startPrank(user);

        bytes memory depositCalldata = abi.encodeWithSelector(
            proxyAsLogic.deposit.selector
        );

        vm.expectRevert();
        (success, ) = address(proxy).call{value: 1 ether}(depositCalldata);
    }

    function testEmergencyWithDraw() public {
        vm.startPrank(user);

        bytes memory depositCalldata = abi.encodeWithSelector(
            proxyAsLogic.deposit.selector
        );
        (bool success, ) = address(proxy).call{value: 1 ether}(depositCalldata);
        assertTrue(success, "Deposit failed through proxy");
        assertEq(proxyAsLogic.totalDeposits(), 1 ether);
        assertEq(user.balance, 0);
        assertEq(address(proxy).balance, 1 ether);

        vm.startPrank(proxyAdmin);

        bytes memory stopEmergencyCalldata = abi.encodeWithSelector(
            proxyAsLogic.stop.selector
        );

        (success, ) = address(proxy).call(stopEmergencyCalldata);

        bytes memory withdrawCalldata = abi.encodeWithSelector(
            proxyAsLogic.emergencyWithdraw.selector,
            user2
        );
        (success, ) = address(proxy).call(withdrawCalldata);
        assertTrue(success, "Withdraw failed through proxy");
        assertEq(address(proxy).balance, 0 ether);
        assertEq(user2.balance, 1 ether);
    }

    function testUpgrade() public {
        vm.startPrank(proxyAdmin);

        DAOUpgradeable newLogic = new DAOUpgradeableV2();

        bytes memory upgradeCalldata = abi.encodeWithSelector(
            proxyAsLogic.upgradeToAndCall.selector,
            address(newLogic),
            ""
        );

        (bool success, ) = address(proxy).call(upgradeCalldata);
        assertTrue(success, "Upgrade failed");

        assertEq(proxyAsLogic.version(), "V2");
    }

    function testUpgradeFail() public {
        vm.startPrank(user);

        DAOUpgradeable newLogic = new DAOUpgradeableV2();

        bytes memory upgradeCalldata = abi.encodeWithSelector(
            proxyAsLogic.upgradeToAndCall.selector,
            address(newLogic),
            ""
        );

        vm.expectRevert();
        (bool success, ) = address(proxy).call(upgradeCalldata);
    }
}
