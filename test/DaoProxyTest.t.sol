// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/UUPSProxy/DAOProxy.sol";
import "../src/UUPSProxy/DAOUpgradeable.sol";
import {console} from "forge-std/console.sol";

contract DAOProxyTest is Test {
    DAOProxy public proxy;
    DAOUpgradeable public logic;
    DAOUpgradeable public proxyAsLogic;

    address public proxyAdmin;
    address public user;

    function setUp() public {
        proxyAdmin = address(this);
        user = address(0x123);

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

    function testDepositReentrancyFail() public {
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
}
