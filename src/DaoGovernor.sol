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
        return super.state(proposalId);
    }

    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) public override(Governor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
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
}
