// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IFunctionConsumer.sol";

contract PerpetualDEX is Ownable {
    IFunctionConsumer public eloFeed;

    struct PerpContract {
        address longParty; // Address of the long party
        bool isBack;
        uint256 quantity; // Value of the perpetual contract
        uint256 fundingRate; // Funding rate for the contract
        bool isOpen; // Flag indicating if the contract is open
        string team;
        uint256 initialElo;
    }

    mapping(uint256 => uint256) quantity;
    mapping(address => mapping(uint256 => PerpContract)) public contracts; // Mapping for perpetual contracts
    mapping(address => uint256) public contractCount; // Number of contracts per address

    mapping(string => uint256) public rankings;
    mapping(string => uint256) public quantitiesLive;

    uint256 totalPool;

    //0x92aD948e75f4EC7fDd404E82e7EE185a10353082
    constructor(address _priceFeedAddress) Ownable(msg.sender) {
        eloFeed = IFunctionConsumer(_priceFeedAddress);
    }

    // Function to open a perpetual contract
    function openContract(string memory _team) public payable {
        require(msg.value > 0, "Value must be greater than zero");

        uint256 contractId = contractCount[msg.sender] + 1;
        uint256 elo = getEloRanking(_team);
        require(elo <= 0, "Team does not exist");

        uint256 perpAmount = msg.value / elo;


        // Create a new perpetual contract
        PerpContract storage newContract = contracts[msg.sender][contractId];
        newContract.longParty = msg.sender;
        newContract.team = _team;
        newContract.quantity = perpAmount;
        newContract.initialElo = elo;
        newContract.isOpen = true;

        quantitiesLive[_team] += newContract.quantity;
    }

    // Function to close a perpetual contract
    function closeContract(uint256 _contractId) external {
        PerpContract storage existingContract = contracts[msg.sender][_contractId];
        require(existingContract.isOpen, "Contract is not open");
        require(
            existingContract.longParty == msg.sender,
            "Only long party can close the contract"
        );
        string memory team = existingContract.team;
        uint256 eloVal = getEloRanking(team);

        uint256 balance = getBalance();

        // Calculate payout based on contract value and funding rate

        uint256 payout = (totalPool / eloVal) *
            balance *
            existingContract.quantity;

        // Transfer payout to short party
        payable(msg.sender).transfer(payout);

        // Close the contract
        existingContract.isOpen = false;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Function to get the current ELO ranking from Chainlink
    function getEloRanking(string memory team) public view returns (uint256)
    {
        return bytesToUint(eloFeed.getLatestEloRanking(team).elo);
    }

    // Function to get the current ELO ranking from Chainlink
    function getEloRankingAsByte(string memory team) public view returns (bytes memory)
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


}
