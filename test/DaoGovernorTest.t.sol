// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DaoGovernor.sol";
import "../src/GovernanceToken.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract DaoGovernorTest is Test {
    DaoGovernor public daoGovernor;
    GovernanceToken public governanceToken;
    TimelockController public timelock;
    address public owner;
    address public user1;
    address public user2;
    address[] public proposers;
    address[] public executors;

    function setUp() public {
        owner = address(this); // Deploying address is the owner
        user1 = address(0x123);
        user2 = address(0x456);

        // Deploy GovernanceToken and mint tokens
        governanceToken = new GovernanceToken(owner);
        governanceToken.mint(owner, 1000 * 10 ** 18);
        governanceToken.mint(user1, 500 * 10 ** 18);
        governanceToken.mint(user2, 300 * 10 ** 18);

        // Deploy TimelockController
        proposers = new address;
        proposers[0] = address(this);
        executors = new address;
        executors[0] = address(this);
        timelock = new TimelockController(1, proposers, executors);

        // Deploy DaoGovernor
        daoGovernor = new DaoGovernor(
            timelock,
            proposers,
            1, // votingDelay
            5, // votingPeriod
            4, // quorumNumerator
            100, // quorumDenominator
            IVotes(address(governanceToken))
        );

        // Set timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(daoGovernor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.TIMELOCK_ADMIN_ROLE(), address(this));
    }

    function testProposeAndVote() public {
        // Approve the governor to spend governance tokens
        governanceToken.delegate(owner);
        governanceToken.delegate(user1);
        governanceToken.delegate(user2);

        // Create a proposal
        address;
        uint256;
        bytes;
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("dummyAction()");

        uint256 proposalId = daoGovernor.propose(
            targets,
            values,
            calldatas,
            "Test Proposal"
        );

        // Check initial state
        DaoGovernor.ProposalState state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(DaoGovernor.ProposalState.Proposed));

        // Wait for the voting delay
        vm.roll(block.number + 2);

        // Cast votes
        daoGovernor.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.For)
        );
        vm.prank(user1);
        daoGovernor.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.For)
        );
        vm.prank(user2);
        daoGovernor.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.Against)
        );

        // Check votes
        (, uint256 votesFor, uint256 votesAgainst, ) = daoGovernor
            .proposalVotes(proposalId);
        assertEq(votesFor, 2 * 1000 * 10 ** 18); // owner and user1 voted "For"
        assertEq(votesAgainst, 1 * 300 * 10 ** 18); // user2 voted "Against"

        // Wait for the voting period to end
        vm.roll(block.number + 6);

        // Execute the proposal
        daoGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked("Test Proposal"))
        );

        // Check state
        state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(DaoGovernor.ProposalState.Executed));
    }

    function dummyAction() external {
        // Dummy action for testing
    }
}
