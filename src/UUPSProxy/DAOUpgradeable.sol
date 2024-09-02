// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../utils/EmergencyStop.sol";
import {console} from "forge-std/console.sol";

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
    bool public isInvestmentActive;
    uint256 public beforeInvestmentBalance;
    mapping(address => uint256) public _balances; // 각 사용자별 예치 금액 관리
    mapping(address => uint256) public _lastDepositBlock; // 사용자의 마지막 예치 블록 기록

    event UpgradeAuthorized(address indexed newImplementation);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event FundsUsed(address indexed recipient, uint256 amount);

    constructor() ERC20("Upgrade Token", "UT") {}

    function initialize(address _owner) public initializer {
        owner = _owner;
        isInvestmentActive = false;
        start();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier notInvestmentActive() {
        require(!isInvestmentActive, "Investment is active");
        _;
    }

    modifier investmentActive() {
        require(isInvestmentActive, "Investment is not active");
        _;
    }

    function version() public pure virtual returns (string memory) {
        return "V1";
    }

    // 공동 자금 예치 기능
    function deposit()
        external
        payable
        notEmergency
        nonReentrant
        notInvestmentActive
    {
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
    ) external payable notEmergency nonReentrant notInvestmentActive {
        require(amount > 0, "Withdraw amount must be greater than zero");
        require(
            _balances[msg.sender] >= amount,
            "Insufficient balance to withdraw"
        );

        // 사용자의 지분(토큰)을 소각하고 자금을 인출
        _burn(msg.sender, amount);

        // 예치 금액 업데이트
        _balances[msg.sender] -= amount;
        if (_balances[msg.sender] == 0) {
            delete _lastDepositBlock[msg.sender];
            delete _balances[msg.sender];
        }
        totalDeposits -= amount;

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    // 투표를 통해 승인된 자금 사용 함수
    function useDepositByVote(
        address recipient,
        uint256 amount
    ) external onlyOwner notEmergency nonReentrant notInvestmentActive {
        require(recipient != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than zero");
        require(totalDeposits >= amount, "Insufficient funds");

        beforeInvestmentBalance = address(this).balance;
        isInvestmentActive = true;

        payable(recipient).transfer(amount);

        emit FundsUsed(recipient, amount);
    }

    // 만약 투자가 성공적으로 이루어지면, 투자 이익을 예치자에게 분배
    // 투자가 실패하면, depositer의 balance를 업데이트(감소)
    function distributeProfits(
        address feeRecipient
    ) external onlyOwner notEmergency nonReentrant investmentActive {
        uint256 contractBalance = address(this).balance; // 컨트랙트의 현재 잔액(분배할 수익)
        require(
            contractBalance > beforeInvestmentBalance,
            "No profits to distribute"
        ); // 분배할 수익이 있는지 확인
        uint256 investmentProfit = contractBalance - beforeInvestmentBalance; // 투자 이익
        require(investmentProfit > 0, "No profits to distribute"); // 분배할 수익이 있는지 확인

        uint256 fee = (investmentProfit * 10) / 100; // 10% 수수료 계산
        uint256 profitAfterFee = investmentProfit - fee; // 수수료 차감 후 남은 수익

        uint256 totalSupply = totalSupply(); // 전체 발행된 토큰 수

        // 10% 수수료는 컨트랙트 소유자에게 전송
        payable(feeRecipient).transfer(fee);

        // 나머지 90%를 각 예치자에게 분배
        for (uint256 i = 0; i < depositors.length; i++) {
            address depositor = depositors[i];
            uint256 depositorBalance = balanceOf(depositor); // 예치자의 토큰 잔액

            if (depositorBalance > 0) {
                // 예치자가 가지고 있는 토큰 비율 계산
                uint256 share = (depositorBalance * profitAfterFee) /
                    totalSupply;

                // 이익을 예치자에게 전송
                payable(depositor).transfer(share);
            }
        }

        isInvestmentActive = false; // 투자 종료
    }

    // 투자 실패 후 예치자의 balance를 업데이트
    function updateUserDepositAfterInvestMentFail()
        external
        onlyOwner
        investmentActive
    {
        uint256 contractBalance = address(this).balance; // 컨트랙트의 현재 잔액
        require(
            contractBalance < beforeInvestmentBalance,
            "Investment is not failed"
        ); // 투자 실패 여부 확인
        uint256 lostAmount = beforeInvestmentBalance - contractBalance; // 투자 실패로 인한 손실 금액

        uint totalLost;
        for (uint256 i = 0; i < depositors.length; i++) {
            if (_balances[depositors[i]] > 0) {
                uint256 lostAmountForDepositor = (_balances[depositors[i]] *
                    lostAmount) / beforeInvestmentBalance; // 예치자의 손실 금액
                _balances[depositors[i]] -= lostAmountForDepositor; // 예치자의 balance 업데이트

                totalLost += lostAmountForDepositor; // 총 예치 금액 업데이트
            }
        }
        totalDeposits -= totalLost;

        isInvestmentActive = false; // 투자 종료
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
