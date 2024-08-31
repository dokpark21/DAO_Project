// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utils/EmergencyStop.sol";

contract DAOUpgradeable is
    Initializable,
    UUPSUpgradeable,
    ERC20,
    ReentrancyGuard,
    EmergencyStop
{
    address public owner;
    uint256 public totalDeposits; // 총 예치 금액
    address[] public depositors; // 예치자 목록
    mapping(address => uint256) private _balances; // 각 사용자별 예치 금액 관리
    mapping(address => uint256) private _lastDepositBlock; // 사용자의 마지막 예치 블록 기록

    event UpgradeAuthorized(address indexed newImplementation);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event FundsUsed(address indexed recipient, uint256 amount);

    constructor() ERC20("Upgrade Token", "UT") {}

    function initialize(address _owner) public initializer {
        owner = _owner;
        start();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function version() public pure virtual returns (string memory) {
        return "V1";
    }

    // 공동 자금 예치 기능
    function deposit() external payable notEmergency nonReentrant {
        require(msg.value > 0, "Deposit amount must be greater than zero");

        // 중복 예치를 방지하기 위해 사용자의 마지막 예치 블록을 확인
        require(
            _lastDepositBlock[msg.sender] != block.number,
            "Deposit already made in this block"
        );

        // 예치된 금액만큼 토큰을 발행하여 사용자에게 할당
        _mint(msg.sender, msg.value);

        // 예치 금액 기록
        _balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        depositors.push(msg.sender);
        _lastDepositBlock[msg.sender] = block.number; // 마지막 예치 블록 업데이트

        emit Deposit(msg.sender, msg.value);
    }

    // 공동 자금 인출 기능
    function withdraw(
        uint256 amount
    ) external payable notEmergency nonReentrant {
        require(amount > 0, "Withdraw amount must be greater than zero");
        require(
            _balances[msg.sender] >= amount,
            "Insufficient balance to withdraw"
        );

        // 사용자의 지분(토큰)을 소각하고 자금을 인출
        _burn(msg.sender, amount);

        // 예치 금액 업데이트
        _balances[msg.sender] -= amount;
        totalDeposits -= amount;

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    // 투표를 통해 승인된 자금 사용 함수
    function useDepositByVote(
        address recipient,
        uint256 amount
    ) external onlyOwner notEmergency nonReentrant {
        require(recipient != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than zero");
        require(totalDeposits >= amount, "Insufficient funds");

        // 자금 전송
        totalDeposits -= amount;

        // 유저 토큰 소각 및 자금 초기화
        uint256 len = depositors.length;
        for (uint256 i = 0; i < len; i++) {
            _burn(depositors[i], amount / len);
            _balances[depositors[i]] = 0;
        }

        payable(recipient).transfer(amount);

        emit FundsUsed(recipient, amount);
    }

    function emergencyWithdraw(address _to) external onlyEmergency onlyOwner {
        selfdestruct(payable(_to));
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {
        require(
            isContract(newImplementation),
            "New implementation must be a contract"
        );
        emit UpgradeAuthorized(newImplementation);
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function stop() public override onlyOwner {
        stopped = true;
    }

    function start() public override onlyOwner {
        stopped = false;
    }
}
