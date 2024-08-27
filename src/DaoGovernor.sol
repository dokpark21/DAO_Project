// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DaoGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    // Proposal state enum to track the state of each proposal
    enum ProposalState {
        None,
        Proposed,
        Voting,
        Executed
    }

    struct Proposal {
        ProposalState state;
        uint256 voteCount;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startBlock;
        uint256 endBlock;
    }

    mapping(uint256 => Proposal) public proposals;

    constructor(
        TimelockController timelock_,
        address[] memory votingOwners,
        uint256 votingDelay_,
        uint256 votingPeriod_,
        uint256 quorumNumerator_,
        uint256 quorumDenominator_,
        IVotes _token
    )
        Governor("DAO")
        GovernorSettings(votingDelay_, votingPeriod_, votingOwners)
        GovernorVotesQuorumFraction(quorumNumerator_)
        GovernorTimelockControl(timelock_)
        GovernorVotes(_token)
    {}

    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) public override(Governor) returns (uint256) {
        uint256 proposalId = super.propose(
            targets,
            values,
            calldatas,
            description
        );

        proposals[proposalId] = Proposal({
            state: ProposalState.Proposed,
            voteCount: 0,
            againstVotes: 0,
            abstainVotes: 0,
            startBlock: block.number + votingDelay(),
            endBlock: block.number + votingDelay() + votingPeriod()
        });

        return proposalId;
    }

    function castVote(
        uint256 proposalId,
        uint8 support
    ) public override returns (uint256) {
        require(
            proposals[proposalId].state == ProposalState.Voting,
            "Proposal not in voting state"
        );
        uint256 weight = token().getPastVotes(msg.sender, block.number - 1);

        if (support == uint8(VoteType.For)) {
            proposals[proposalId].voteCount += weight;
        } else if (support == uint8(VoteType.Against)) {
            proposals[proposalId].againstVotes += weight;
        } else if (support == uint8(VoteType.Abstain)) {
            proposals[proposalId].abstainVotes += weight;
        } else {
            revert("Invalid vote type");
        }

        super._castVote(proposalId, msg.sender, support, "");

        return weight;
    }

    function execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override(Governor) {
        require(
            proposals[proposalId].state == ProposalState.Proposed,
            "Proposal not in proposed state"
        );
        require(
            block.number > proposals[proposalId].endBlock,
            "Voting period has not ended"
        );
        require(
            proposals[proposalId].voteCount >= quorum(),
            "Proposal does not meet quorum"
        );

        super._execute(proposalId, targets, values, calldatas, descriptionHash);
        proposals[proposalId].state = ProposalState.Executed;
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        uint256 proposalId
    ) internal override(Governor, GovernorTimelockControl) {
        require(
            proposals[proposalId].state != ProposalState.Executed,
            "Proposal already executed"
        );
        proposals[proposalId].state = ProposalState.None;
        super._cancel(proposalId);
    }

    function _executor()
        internal
        view
        virtual
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function _supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super._supportsInterface(interfaceId);
    }

    function votingDelay()
        public
        view
        virtual
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        virtual
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function proposalThreshold()
        public
        view
        virtual
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function setVotingDelay(
        uint256 newVotingDelay
    ) public override(GovernorSettings) onlyGovernance {
        super._setVotingDelay(newVotingDelay);
    }

    function setVotingPeriod(
        uint256 newVotingPeriod
    ) public override(GovernorSettings) onlyGovernance {
        super._setVotingPeriod(newVotingPeriod);
    }

    function setProposalThreshold(
        uint256 newProposalThreshold
    ) public override(GovernorSettings) onlyGovernance {
        super._setProposalThreshold(newProposalThreshold);
    }

    function quorum()
        public
        view
        virtual
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum();
    }

    function state(
        uint256 proposalId
    )
        public
        view
        virtual
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return proposals[proposalId].state;
    }
}
