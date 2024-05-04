// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Current 0x92aD948e75f4EC7fDd404E82e7EE185a10353082s
interface IFunctionConsumer {
    struct ELOInfo {
        bytes elo;
        uint256 timestamp;
    }

    function getLatestEloRanking(string memory teamId)
        external
        view
        returns (ELOInfo memory);

    function getTeamEloRankingsAtPoint(string memory teamId, uint256 index)
        external
        view
        returns (ELOInfo memory);

    function getTeamEloCount(string memory teamName)
        external
        view
        returns (uint256);

    // Additional functions can be added here based on the contract's functionality
}
