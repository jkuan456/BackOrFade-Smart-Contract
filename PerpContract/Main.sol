// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract PerpetualDEX is Ownable {
    struct PerpContract {
        address longParty; // Address of the long party
        bool isBack;
        uint256 value; // Value of the perpetual contract
        uint256 fundingRate; // Funding rate for the contract
        bool isOpen; // Flag indicating if the contract is open
        string team;
    }
    //


    // function calculateImbalance() {
    //     return false;
    // }


    mapping(uint256 => uint256) quantity;
    mapping(address => mapping(uint256 => PerpContract)) public contracts; // Mapping for perpetual contracts
    mapping(address => uint256) public contractCount; // Number of contracts per address

    mapping(string => uint) public rankings;


    AggregatorV3Interface public priceFeed; // Chainlink price feed for ELO rankings


    constructor(address _priceFeedAddress) Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);

        // Initialise Test Values
        rankings["Arsenal"] = 1900;
        rankings["Chelsea"] = 2000;
        rankings["Man City"] = 1800;

    }


    // Function to open a perpetual contract
    function openContract(address _shortParty, bool isBack) external payable {
        require(msg.value > 0, "Value must be greater than zero");
        require(_shortParty != address(0), "Invalid short party address");


        uint256 contractId = contractCount[msg.sender] + 1;




        // Create a new perpetual contract
        PerpContract storage newContract = contracts[msg.sender][contractId];
        newContract.longParty = msg.sender;
        newContract.isBack = isBack; // fadeh
        newContract.value = msg.value;
        newContract.isOpen = true;


        // Increment contract count for the address
        contractCount[msg.sender]++;
    }


    // Function to close a perpetual contract
    function closeContract(uint256 _contractId) external {
        PerpContract storage existingContract = contracts[msg.sender][_contractId];
        require(existingContract.isOpen, "Contract is not open");
        require(existingContract.longParty == msg.sender, "Only long party can close the contract");


        // Calculate payout based on contract value and funding rate
        uint256 payout = existingContract.value + (existingContract.value * existingContract.fundingRate);
       
        // Transfer payout to short party
        payable(msg.sender).transfer(payout);
       


        // Close the contract
        existingContract.isOpen = false;
    }


    // Function to update funding rate (to be called periodically)
    function updateFundingRate(uint256 _newRate, address _shortParty, uint256 _contractId) external onlyOwner {
        PerpContract storage existingContract = contracts[_shortParty][_contractId];
        require(existingContract.isOpen, "Contract is not open");


        existingContract.fundingRate = _newRate;
    }


    // Function to get the current ELO ranking from Chainlink
    function getEloRanking() external view returns (int) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return price;
    }
}



