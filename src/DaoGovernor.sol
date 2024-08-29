// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "forge-std/console.sol";

contract DaoGovernor is
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
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
        IVotes _token,
        TimelockController timelock_,
        uint48 votingDelay_,
        uint32 votingPeriod_,
        uint256 proposalThreshold_,
        uint256 quorumNumerator_
    )
        Governor("DAO")
        GovernorSettings(votingDelay_, votingPeriod_, proposalThreshold_)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(quorumNumerator_)
        GovernorTimelockControl(timelock_)
    {}

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns (uint256) {
        uint256 proposalId = super.propose(
            targets,
            values,
            calldatas,
            description
        );

        proposals[proposalId] = Proposal({
            state: ProposalState.Pending,
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
    ) public override(Governor) returns (uint256) {
        require(
            state(proposalId) == ProposalState.Active,
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

        return super.castVote(proposalId, support);
    }

    function execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Governor: proposal not successful"
        );

        super.execute(targets, values, calldatas, descriptionHash);
        proposals[proposalId].state = ProposalState.Executed;
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        require(
            state(proposalId) != ProposalState.Executed,
            "Governor: proposal already executed"
        );
        proposals[proposalId].state = ProposalState.Canceled;
        return super._cancel(targets, values, calldatas, descriptionHash);
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
        return super.state(proposalId);
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

    function quorum(
        uint256 blockNumber
    )
        public
        view
        virtual
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
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

    function _supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return _supportsInterface(interfaceId);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    function _queueOperations(
        uint256 propsalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return
            super._queueOperations(
                propsalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    )
        public
        view
        virtual
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory data
    )
        internal
        view
        virtual
        override(Governor, GovernorVotes)
        returns (uint256)
    {
        return super._getVotes(account, blockNumber, data);
    }
}
