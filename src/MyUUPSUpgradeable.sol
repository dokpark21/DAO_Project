// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAOUpgradeable is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC20
{
    bool public emergencyStopped;
    uint256 public totalDeposits;
    mapping(address => uint256) private _balances; // 각 사용자별 예치 금액 관리
    address[] public depositors;

    event UpgradeAuthorized(address indexed newImplementation);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event FundsUsed(address indexed recipient, uint256 amount);

    function initialize(address _initialOwner) public initializer {
        __Ownable_init(_initialOwner); // Ownable 초기화
        __ERC20_init("DAO Token", "DAO"); // ERC20 토큰 초기화
        emergencyStopped = false;
    }

    modifier notEmergency() {
        require(!emergencyStopped, "Emergency stop is active");
        _;
    }

    modifier onlyEmergency() {
        require(emergencyStopped, "Not Emergency");
        _;
    }

    function stopEmergency() external onlyOwner {
        emergencyStopped = true; // 긴급 멈춤 활성화
    }

    function version() public pure virtual override returns (string memory) {
        return "V1";
    }

    // 공동 자금 예치 기능
    function deposit() external payable notEmergency {
        require(msg.value > 0, "Deposit amount must be greater than zero");

        // 예치된 금액만큼 토큰을 발행하여 사용자에게 할당
        _mint(msg.sender, msg.value);

        // 예치 금액 기록
        _balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        depositors.push(msg.sender);

        emit Deposit(msg.sender, msg.value);
    }

    // 공동 자금 인출 기능
    // Pull over push
    function withdraw(uint256 amount) external notEmergency {
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

    // Implement use Deposit by vote
    // 투표를 통해 승인된 자금 사용 함수
    function useDepositByVote(
        address recipient,
        uint256 amount
    ) external onlyOwner notEmergency {
        require(recipient != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than zero");
        require(totalDeposits >= amount, "Insufficient funds");

        // DAO의 투표를 통해 자금 사용이 승인되었는지 확인해야 함 => 이 함수는 DAO 컨트랙트에서 호출하여 투표 승인 여부를 확인하고 이 함수를 실행
        // DAO 컨트랙트에서 호출하여 투표 승인 여부를 확인하고 이 함수를 실행

        // 자금 전송
        totalDeposits -= amount;
        // 유저 토큰 소각 및 자금 초기화
        uint256 len = depositors.length;
        for (int i = 0; i < len; i++) {
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
}
