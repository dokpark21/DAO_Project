// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20 {
    mapping(address => address) public _delegates;
    mapping(address => mapping(uint32 => Checkpoint)) public _checkpoints;
    mapping(address => uint32) public _numCheckpoints;
    mapping(address => uint) public _nonces;

    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    constructor(
        address _initOwner
    ) ERC20("Governance Token", "GTK") Ownable(_initOwner) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        transferOwnership(newOwner);
    }

    function getBalance(address account) public view returns (uint256) {
        return balanceOf(account);
    }

    function getOwner() public view returns (address) {
        return owner();
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        return super.approve(spender, amount);
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public override returns (bool) {
        return super.increaseAllowance(spender, addedValue);
    }

    // IVotes 인터페이스 구현

    function getVotes(address account) public view override returns (uint256) {
        uint32 checkpointCount = _numCheckpoints[account];
        return
            checkpointCount > 0
                ? _checkpoints[account][checkpointCount - 1].votes
                : 0;
    }

    function getPastVotes(
        address account,
        uint256 blockNumber
    ) public view override returns (uint256) {
        require(
            blockNumber < block.number,
            "GovernanceToken: block not yet mined"
        );

        uint32 checkpointCount = _numCheckpoints[account];
        if (checkpointCount == 0) {
            return 0;
        }

        // Check the most recent balance first
        if (
            _checkpoints[account][checkpointCount - 1].fromBlock <= blockNumber
        ) {
            return _checkpoints[account][checkpointCount - 1].votes;
        }

        // Check the oldest balance
        if (_checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        // Binary search to find the correct checkpoint
        uint32 lower = 0;
        uint32 upper = checkpointCount - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // avoid overflow
            VotingCheckpoint memory cp = _checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return _checkpoints[account][lower].votes;
    }

    function delegate(address delegatee) public override {
        _delegate(msg.sender, delegatee);
    }

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                chainId,
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "GovernanceToken: invalid signature");
        require(nonce == _nonces[signer]++, "GovernanceToken: invalid nonce");
        require(
            block.timestamp <= expiry,
            "GovernanceToken: signature expired"
        );

        _delegate(signer, delegatee);
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegateVotes(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegateVotes(
        address fromDelegate,
        address toDelegate,
        uint256 amount
    ) internal {
        if (fromDelegate != toDelegate && amount > 0) {
            if (fromDelegate != address(0)) {
                uint32 fromRepNum = _numCheckpoints[fromDelegate];
                uint256 fromRepOld = fromRepNum > 0
                    ? _checkpoints[fromDelegate][fromRepNum - 1].votes
                    : 0;
                require(
                    fromRepOld >= amount,
                    "GovernanceToken: delegate has no votes to delegate"
                );
                uint256 fromRepNew = fromRepOld - amount;
                _writeCheckpoint(
                    fromDelegate,
                    fromRepNum,
                    fromRepOld,
                    fromRepNew
                );
            }

            if (toDelegate != address(0)) {
                uint32 toRepNum = _numCheckpoints[toDelegate];
                uint256 toRepOld = toRepNum > 0
                    ? _checkpoints[toDelegate][toRepNum - 1].votes
                    : 0;
                uint256 toRepNew = toRepOld + amount;
                _writeCheckpoint(toDelegate, toRepNum, toRepOld, toRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal {
        uint32 blockNumber = safe32(
            block.number,
            "_writeCheckpoint: block number exceeds 32 bits"
        );

        if (
            nCheckpoints > 0 &&
            _checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            _checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            _checkpoints[delegatee][nCheckpoints] = VotingCheckpoint(
                blockNumber,
                newVotes
            );
            _numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(
        uint n,
        string memory errorMessage
    ) internal pure returns (uint32) {
        require(n < 2 ** 32, errorMessage);
        return uint32(n);
    }
}
