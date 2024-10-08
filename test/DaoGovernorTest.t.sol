// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/governance/DaoGovernor.sol";
import "../src/governance/GovernanceToken.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";


contract DaoGovernorTest is Test {
    DaoGovernor public daoGovernor;
    GovernanceToken public governanceToken;
    TimelockController public timelock;
    address public owner;
    address public user1;
    address public user2;
    address[] public proposers;
    address[] public executors;

    address[] targets = new address[](1);
    uint256[] values = new uint256[](1);
    bytes[] calldatas = new bytes[](1);

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
        proposers.push(address(this));
        executors.push(address(this));
        timelock = new TimelockController(
            1,
            proposers,
            executors,
            address(this)
        );

        // Set timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(daoGovernor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(
            timelock.PROPOSER_ROLE(),
            0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
        );
        timelock.grantRole(
            timelock.CANCELLER_ROLE(),
            0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
        );

        // Deploy DaoGovernor
        daoGovernor = new DaoGovernor(
            IVotes(address(governanceToken)),
            timelock,
            1, // votingDelay
            5, // votingPeriod
            100 * 10 ** 18, // proposalThreshold
            4 // quorumNumerator
        );
    }

    function testProposeAndVote() public {
        // Approve the governor to spend governance tokens
        governanceToken.delegate(owner);
        vm.prank(user1);
        governanceToken.delegate(user1);
        vm.prank(user2);
        governanceToken.delegate(user2);

        vm.roll(block.number + 1);

        // Create a proposal
        address;
        uint256;
        bytes;
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("dummyAction()");

        vm.prank(owner);
        uint256 proposalId = daoGovernor.propose(
            targets,
            values,
            calldatas,
            "Test Proposal"
        );

        // Check initial state
        DaoGovernor.ProposalState state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(0));

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
        (uint256 votesAgainst, uint256 votesFor, ) = daoGovernor.proposalVotes(
            proposalId
        );
        assertEq(votesFor, 1500 * 10 ** 18); // owner and user1 voted "For"
        assertEq(votesAgainst, 1 * 300 * 10 ** 18); // user2 voted "Against"

        // Wait for the voting period to end
        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 10);

        // Governor execute -> GovernorTimeControl _executeOperations -> TimelockController executeBatch
        daoGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked("Test Proposal"))
        );

        // Check state
        state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(7));
    }

    function testProposeAndVoteRejected() public {
        // Approve the governor to spend governance tokens
        governanceToken.delegate(owner);
        vm.prank(user1);
        governanceToken.delegate(user1);
        vm.prank(user2);
        governanceToken.delegate(user2);

        vm.roll(block.number + 1);

        // Create a proposal
        address;
        uint256;
        bytes;
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("dummyAction()");

        vm.prank(owner);
        uint256 proposalId = daoGovernor.propose(
            targets,
            values,
            calldatas,
            "Test Proposal"
        );

        // Check initial state
        DaoGovernor.ProposalState state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(0));

        // Wait for the voting delay
        vm.roll(block.number + 2);

        // Cast votes (this time, majority votes "Against")
        daoGovernor.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.Against)
        );
        vm.prank(user1);
        daoGovernor.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.Against)
        );
        vm.prank(user2);
        daoGovernor.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.For)
        );

        // Check votes
        (uint256 votesAgainst, uint256 votesFor, ) = daoGovernor.proposalVotes(
            proposalId
        );
        assertEq(votesFor, 300 * 10 ** 18); // user2 voted "For"
        assertEq(votesAgainst, (1000 + 500) * 10 ** 18); // owner and user1 voted "Against"

        // Wait for the voting period to end
        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 10);

        vm.prank(owner);
        vm.expectRevert();

        // Try to execute the proposal (should fail)
        daoGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked("Test Proposal"))
        );

        // Check that the proposal state is set to Defeated
        state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(3)); // 3 corresponds to ProposalState.Defeated
    }

    function testDuplicateVoteRejection() public {
        // Delegate tokens
        governanceToken.delegate(owner);
        vm.roll(block.number + 1);

        // Create a proposal
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("dummyAction()");

        vm.prank(owner);
        uint256 proposalId = daoGovernor.propose(
            targets,
            values,
            calldatas,
            "Test Proposal"
        );

        // Check initial state
        DaoGovernor.ProposalState state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(0));

        // Wait for the voting delay
        vm.roll(block.number + 2);

        // Cast a vote
        daoGovernor.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.For)
        );

        // Attempt to cast a second vote by the same voter and expect it to fail
        vm.expectRevert();
        daoGovernor.castVote(
            proposalId,
            uint8(GovernorCountingSimple.VoteType.For)
        );
    }

    function testProposalCancellation() public {
        // Delegate tokens
        governanceToken.delegate(owner);
        vm.roll(block.number + 1);

        // Create a proposal
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("dummyAction()");

        vm.prank(owner);
        uint256 proposalId = daoGovernor.propose(
            targets,
            values,
            calldatas,
            "Test Proposal"
        );

        // Check initial state
        DaoGovernor.ProposalState state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(0));

        // Cancel the proposal
        vm.prank(owner);
        daoGovernor.cancel(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked("Test Proposal"))
        );

        // Check that the proposal state is Canceled
        state = daoGovernor.state(proposalId);
        assertEq(uint(state), uint(2)); // 2 corresponds to ProposalState.Canceled
    }

    function testUnauthorizedRoleAccess() public {
        // Unauthorized user attempts to propose
        vm.prank(user2);
        vm.expectRevert();
        daoGovernor.propose(
            targets,
            values,
            calldatas,
            "Unauthorized Proposal"
        );

        // Unauthorized user attempts to execute
        vm.prank(user2);
        vm.expectRevert();
        daoGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked("Test Proposal"))
        );
    }

    function testDuplicateProposalRejection() public {
        // Delegate tokens
        governanceToken.delegate(owner);
        vm.roll(block.number + 1);

        // Create a proposal
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("dummyAction()");

        vm.prank(owner);
        uint256 proposalId1 = daoGovernor.propose(
            targets,
            values,
            calldatas,
            "Test Proposal"
        );

        // Attempt to create the same proposal again
        vm.expectRevert();
        uint256 proposalId2 = daoGovernor.propose(
            targets,
            values,
            calldatas,
            "Test Proposal"
        );
    }

    function dummyAction() external {
        // Dummy action for testing
    }
}
