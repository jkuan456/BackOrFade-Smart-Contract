// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IFunctionConsumer.sol";

contract PerpetualDEX is Ownable {
    IFunctionConsumer public eloFeed;

    struct PerpContract {
        uint256 id;
        address longParty; // Address of the long party
        bool isBack;
        uint256 quantity; // Value of the perpetual contract
        uint256 fundingRate; // Funding rate for the contract
        bool isOpen; // Flag indicating if the contract is open
        string team;
        uint256 initialAmount;
        uint256 initialElo;
    }

    mapping(uint256 => uint256) quantity;
    mapping(address => mapping(uint256 => PerpContract)) public contracts; // Mapping for perpetual contracts
    mapping(address => uint256) public contractCount; // Number of contracts per address

    mapping(string => mapping(uint256 => PerpContract)) public teamContracts;
    mapping(string => uint256) public teamContractsCount;

    function getContracts() public view returns (PerpContract[] memory) {
        uint256 count = contractCount[msg.sender];
        PerpContract[] memory userContracts = new PerpContract[](count);

        for (uint256 i = 0; i < count; i++) {
            PerpContract memory contractData = contracts[msg.sender][i];
            userContracts[i] = contractData;
        }

        return userContracts;
    }

    function getTeamContracts(string memory team)
        public
        view
        returns (PerpContract[] memory)
    {
        uint256 count = teamContractsCount[team];
        PerpContract[] memory userContracts = new PerpContract[](count);

        for (uint256 i = 0; i < count; i++) {
            PerpContract memory contractData = teamContracts[team][i];
            userContracts[i] = contractData;
        }

        return userContracts;
    }

    mapping(string => uint256) public rankings;
    mapping(string => uint256) public quantitiesLive;
    string[] public teamNames;

    uint256 totalPool;

    //0x92aD948e75f4EC7fDd404E82e7EE185a10353082
    constructor(address _priceFeedAddress) Ownable(msg.sender) {
        eloFeed = IFunctionConsumer(_priceFeedAddress);
        // Initialise Teamnames;
        teamNames = ["Arsenal", "Chelsea", "Man City", "Liverpool"];
        // Dummy Data
        rankings["Arsenal"] = 1900;
        rankings["Chelsea"] = 2000;
        rankings["Man City"] = 1800;
        rankings["Liverpool"] = 1800;
    }

    // Function to open a perpetual contract
    function openContract(string memory _team) public payable {
        require(msg.value > 0, "Value must be greater than zero");

        uint256 contractId = contractCount[msg.sender];
        uint256 teamId = teamContractsCount[_team];
        uint256 elo = getEloRanking(_team);
        //uint256 elo = rankings[_team];
        require(elo > 0, "Team does not exist");

        uint256 perpAmount = msg.value / elo;

        // Create a new perpetual contract
        PerpContract storage newContract = contracts[msg.sender][contractId];
        newContract.longParty = msg.sender;
        newContract.team = _team;
        newContract.quantity = perpAmount;
        newContract.initialElo = elo;
        newContract.isOpen = true;
        newContract.id = contractId;
        newContract.initialAmount = msg.value;

        teamContracts[_team][teamId] = contracts[msg.sender][contractId];
        teamContractsCount[_team] += 1;

        quantitiesLive[_team] += newContract.quantity;
        contractCount[msg.sender] += 1;
    }

    // Function to close a perpetual contract
    function closeContract(uint256 _contractId) external {
        PerpContract storage existingContract = contracts[msg.sender][
            _contractId
        ];
        PerpContract storage teamContract = contracts[msg.sender][_contractId];
        require(existingContract.isOpen, "Contract is not open");
        require(
            existingContract.longParty == msg.sender,
            "Only long party can close the contract"
        );

        string memory team = existingContract.team;

        uint256 payout = calcPayout(_contractId);
        // Transfer payout to short party
        payable(msg.sender).transfer(payout);
        // Close the contract
        existingContract.isOpen = false;
        teamContract.isOpen = false;
        quantitiesLive[team] -= existingContract.quantity;
    }

    function calcPayout(uint256 _contractId) public view returns (uint256) {
        PerpContract storage existingContract = contracts[msg.sender][
            _contractId
        ];
        string memory team = existingContract.team;
        uint256 eloVal = getEloRanking(team);
        //uint256 eloVal = rankings[team];

        uint256 balance = getBalance();
        uint256 totalVal = findTotalVal();

        // Calculate payout based on contract value and funding rate

        uint256 payout = (existingContract.quantity * eloVal * balance) /
            totalVal;
        return payout;
    }

    function findTotalVal() public view returns (uint256) {
        uint256 totalVal = 0;
        for (uint256 i = 0; i < teamNames.length; i++) {
            string memory team = teamNames[i];
            uint256 eloVal = getEloRanking(team);
            //uint256 eloVal = rankings[team];
            totalVal += quantitiesLive[team] * eloVal;
        }

        return totalVal;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Function to get the current ELO ranking from Chainlink
    function getEloRanking(string memory team) public view returns (uint256) {
        //rankings[team] = bytesToUint(eloFeed.getLatestEloRanking(team).elo);
        return bytesToUint(eloFeed.getLatestEloRanking(team).elo);
    }

    // Function to get the current ELO ranking from Chainlink
    function getEloRankingAsByte(string memory team)
        public
        view
        returns (bytes memory)
    {
        return eloFeed.getLatestEloRanking(team).elo;
    }

    function bytesToUint(bytes memory b) public pure returns (uint256) {
        require(b.length == 32, "Bytes length must be 32");

        uint256 number1;
        assembly {
            number1 := mload(add(b, 32))
        }
        return number1;
    }

    // Function to set the ranking of a club
    function setRanking(string memory club, uint256 ranking) public {
        rankings[club] = ranking;
    }

    // Function to get the ranking of a club
    function getRanking(string memory club) public view returns (uint256) {
        return rankings[club];
    }

    // Function to add a team name to the list
    function addTeamName(string memory _teamName) public {
        teamNames.push(_teamName);
    }
}
