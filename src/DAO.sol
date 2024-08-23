// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

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
}
