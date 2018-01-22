pragma solidity ^0.4.18;

import "./PayrollInterface.sol";
import "../DateTime/DateTimeInterface.sol";
import "../Token/ERC223ReceivingContract.sol";
import "../Token/EIP20.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

/// @title Payroll
/// @dev Smart contract to pay employees
contract Payroll is PayrollInterface, Ownable, ERC223ReceivingContract {
    /*
     * Events
     */
    event EmployeeAdded(uint employeeId);
    event EmployeeRemoved(uint lastPayDay);
    event EtherReceived(address from, uint value);
    event TokenReceived(address from, uint value, bytes data);
    event UnsuffisantFund(address tokenAddress);
    event PayementError(address tokenAddress, uint valueToSend);
    event EscapeSuccess(bool success);

    /*
     * Storage
     */
    address internal oracle;
    uint256 internal employeeCount = 0;
    uint256 internal nextEmployeeId = 0;
    uint256 internal totalYearlyEURSalary = 0;
    // Employee
    struct Employee {
        address employeeAddress;
        uint256 yearlyEURSalary;
        address[] allowedTokens;
        uint256[] tokenDistribution;
        uint256 lastDistributionUpdate;
        uint256 lastPayDay;
    }
    Employee[] employeeList;
    mapping(address => uint) employeeIds;
    // Token
    struct Token {
        address tokenAddress;
        uint256 EURRate;
    }
    Token[] tokenList;
    uint256 internal nextTokenId = 0;
    mapping(address => uint) tokenIds;
    mapping(address => uint) tokenYearlyNeeds;

    /*
     * Modifier
     */
    modifier onlyEmployee() {
        require(employeeIds[msg.sender] > 0);
        _;
    }
    modifier onlyOracle() {
        require(msg.sender == oracle);
        _;
    }
    /*
     * Public Functions
     */
    /// @dev Payroll(): instantiates the smart contract
    /// @param _oracle the oracle contract address
    function Payroll(address _oracle) public {
        _oracle = oracle;
    }

    /// @dev addEmployee(): instantiates a new employee
    /// @param accountAddress the employee's eth address
    /// @param allowedTokens the list of the authorized tokens
    /// @param initialDistribution the distribution in % of how the employee wants to be paid
    /// @param initialYearlyEURSalary the employee's salary in EUR
    function addEmployee(address accountAddress, address[] allowedTokens, uint256[] initialDistribution, uint256 initialYearlyEURSalary) public onlyOwner {
        require(allowedTokens.length == initialDistribution.length);
        employeeList[nextEmployeeId] = Employee(accountAddress, initialYearlyEURSalary, allowedTokens, initialDistribution, 0, now);
        nextEmployeeId++;
        employeeCount++;
        employeeIds[accountAddress] = nextEmployeeId;
        updateTotalYearlySalary(0, initialYearlyEURSalary);
        for (uint i = 0; i < allowedTokens.length; i++) {
            address _tokenAddress = allowedTokens[i];          
            if (!(tokenIds[_tokenAddress] > 0)) {
                Token memory _token = Token(_tokenAddress, 0);
                nextTokenId++;
                tokenIds[_tokenAddress] = nextTokenId;
                tokenList[nextTokenId] = _token;            
            }
        }
        EmployeeAdded(nextEmployeeId);
    }

    /// @dev setEmployeeSalary(): Edit the employee salary
    /// @param employeeId the employee unique Id
    /// @param yearlyEURSalary the updated employee's salary
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) public onlyOwner {
        updateTotalYearlySalary(employeeList[employeeId].yearlyEURSalary, yearlyEURSalary);
        employeeList[employeeId].yearlyEURSalary = yearlyEURSalary;
    }

    /// @dev removeEmployee(): remove an employee form the
    /// @param employeeId the employee unique Is
    function removeEmployee(uint256 employeeId) public onlyOwner {
        uint _lastPayDay = employeeList[employeeId].lastPayDay;
        updateTotalYearlySalary(employeeList[employeeId].yearlyEURSalary, 0);
        delete employeeIds[employeeList[employeeId].employeeAddress];
        delete employeeList[employeeId];
        employeeCount--;
        EmployeeRemoved(_lastPayDay);
    }

    /// Payable
    /// @dev addFunds(): Method to add funds to the smart contract
    function addFunds() public payable onlyOwner {
        EtherReceived(msg.sender, msg.value);
    }

    /// @dev escapeHatch(): Send all the funds to the owner
    function escapeHatch() public onlyOwner {
        bool TransfersSucceeded = true;
        // Send all the tokens
        for (uint i; i < tokenList.length; i++) {
            address _token = tokenList[i].tokenAddress;
            uint tokenBalance = EIP20(_token).balanceOf(this);
            if (tokenBalance > 0 && !EIP20(_token).transfer(owner, tokenBalance)) {
                TransfersSucceeded = false;
            }
        }
        // Send the ethers
        owner.transfer(this.balance);
        EscapeSuccess(TransfersSucceeded);
        selfdestruct(owner);
    }

    /// @dev tokenFallback(): Allow the reception of ERC223 tokens
    /// @param from  Token sender address.
    /// @param value Amount of tokens.
    /// @param data  Transaction metadata.
    function tokenFallback(address from, uint value, bytes data) public {
        TokenReceived(from, value, data);
    }

    /// @dev getEmployeeCount(): returns the number of employees
    function getEmployeeCount() onlyOwner constant public returns (uint256) {
        return employeeCount;
    }

    /// @dev getEmployee(): returns important employee's information given an ID
    /// @param employeeId employee's unique ID
    function getEmployee(uint256 employeeId) onlyOwner constant public returns (address employee, uint256 yearlyEURSalary, uint256 lastDistributionUpdate, uint256 lastPayDay) {
        Employee storage _employee = employeeList[employeeId];
        return (_employee.employeeAddress, _employee.yearlyEURSalary, _employee.lastDistributionUpdate, _employee.lastPayDay);
    }

    /// @dev calculatePayrollBurnrate(): Monthly EUR amount spent
    function calculatePayrollBurnrate() onlyOwner constant public returns (uint256) {
        return totalYearlyEURSalary / 12;
    }

    /// @dev calculatePayrollRunway(): Days until the contract can run out of funds
    function calculatePayrollRunway() onlyOwner constant returns (uint256) {
        uint256[] memory balances = new uint256[](tokenList.length);
        
        for (uint256 i = 0; i < tokenList.length; i++){
            Token storage _token = tokenList[i];
            balances[i] = EIP20(_token.tokenAddress).balanceOf(this);
            tokenYearlyNeeds[_token.tokenAddress] = 0;  
        }
        
        for (uint256 j = 0; j < employeeList.length; j++) {
            Employee storage _employee = employeeList[j];
            for (uint256 k = 0; k < _employee.allowedTokens.length; k++) {
                tokenYearlyNeeds[_employee.allowedTokens[k]] += _employee.yearlyEURSalary * _token.EURRate * _employee.tokenDistribution[k] / 100;
            }
        }
        
        uint256 daysBeforeRunway = balances[0] / tokenYearlyNeeds[0] * 365;
        for (uint256 l = 1; l < tokenList.length; l++){
            uint256 tempRunway = balances[l] / tokenYearlyNeeds[tokenList[l].tokenAddress] * 365;
            if (daysBeforeRunway > tempRunway) {
                daysBeforeRunway = tempRunway;
            }
        }
        return daysBeforeRunway;    
    }

    /// @dev determineAllocation(): Determines with which tokens the employee wants to be paid
    /// @param tokens is an array of token address
    /// @param distribution array of integer representing the wanted token distribution in %
    /// @notice Can only be called every 6 months
    function determineAllocation(address[] tokens, uint256[] distribution) public onlyEmployee {
        Employee storage _employee = employeeList[employeeIds[msg.sender]];
        // Check that the last allocation was more than 6 months ago
        require(now > addMonths(6, _employee.lastDistributionUpdate));
        // Check that the arrays are the same size
        require(tokens.length == distribution.length);
        // Check the total distribution is equal to 100%
        uint256 totalPercentage = 0;
        for (uint i = 0; i < distribution.length; i++) {
            totalPercentage +=  distribution[i];
        }
        require(totalPercentage == 100);

        uint256[] memory newDistribution = new uint256[](_employee.allowedTokens.length);
        for (uint j = 0; j < distribution.length; j++) {
            bool result = false;
            for (uint k = 0; k < _employee.allowedTokens.length; k++) {
                if(tokens[j] == _employee.allowedTokens[k]){
                    result = true;
                    newDistribution[k] = distribution[j];
                }
            }
            if(!result){
                revert();
            }
        }
        _employee.tokenDistribution = newDistribution;
        _employee.lastDistributionUpdate = now;
    }

    /// @dev payday(): send employee's salary
    /// @notice can only be called once a month
    function payday() public onlyEmployee {
        Employee storage _employee = employeeList[employeeIds[msg.sender]];

        // Check if the last pay day was more than a month ago
        require(now > addMonths(1, _employee.lastPayDay));

  	    bool enoughFund = true;
        uint[] memory tokenToSend = new uint[](_employee.allowedTokens.length);
        // Check if the contract has enough funds
        address tokenAddress;
	    for (uint i; i < _employee.allowedTokens.length; i++) {
            tokenAddress = _employee.allowedTokens[i];
            if (_employee.tokenDistribution[i] == 0) {
                    tokenToSend[i] = 0;
  		            continue;
  	        }
  		    else {
  		        uint tokenBalance = EIP20(tokenAddress).balanceOf(this);
                uint tokenRate = tokenList[tokenIds[tokenAddress]].EURRate;
      			tokenToSend[i] = (_employee.yearlyEURSalary / 12) * tokenRate * _employee.tokenDistribution[i] / 100;
      			if (tokenBalance < tokenToSend[i]) {
      		        enoughFund = false;
      			    UnsuffisantFund(tokenAddress);
                    revert();
      		    }
  		    }
  		}
        // Pay the employee, send the tokens
        for (uint j; j < _employee.allowedTokens.length; j++) {
            tokenAddress = _employee.allowedTokens[j];
            if (tokenToSend[j] == 0) {
                continue;
            }
            if (!EIP20(tokenAddress).transfer(_employee.employeeAddress, tokenToSend[j])) {
                PayementError(_employee.allowedTokens[j], tokenToSend[j]);
            }
        }
        _employee.lastPayDay = addMonths(1, _employee.lastPayDay);
    }

    /// @dev setExchangeRate(): Update token exchange rate
    /// @param token the smart contract address
    /// @param EURExchangeRate the new rate
    function setExchangeRate(address token, uint256 EURExchangeRate) public onlyOracle{
        tokenList[tokenIds[token]].EURRate = EURExchangeRate;
    }

    /*
     * Internal Functions
     */

     /// @dev updateTotalYearlySalary():
     /// @param oldSalary the current salary being updated
     /// @param newSalary the new value
    function updateTotalYearlySalary (uint256 oldSalary, uint newSalary) internal {
        totalYearlyEURSalary -= oldSalary;
        totalYearlyEURSalary += newSalary;
    }

     /// @dev addMonths(): add a unit of month to a timestamp
     /// @param months the number of months to add
     /// @param timestamp the Date and time that needs to be modify
     /// @return the new calculated timestamp
    function addMonths(uint8 months, uint256 timestamp) internal returns (uint256) {
         // Address for the Kovan Testnet
        DateTimeInterface _dateTime = DateTimeInterface(address(0x8Fc065565E3e44aef229F1D06aac009D6A524e82));
        uint16 year = _dateTime.getYear(timestamp);
        uint8 month = _dateTime.getMonth(timestamp);
        // Add the number of months and increment the year if needed
        month += months;
        if (month > 12) {
            month -= 12;
            year++;
        }
        // Check the length of the new month
        uint8 lengthMonth = _dateTime.getDaysInMonth(month, year);
        uint8 day = _dateTime.getDay(timestamp);
        if (day > lengthMonth) {
            day = lengthMonth;
        }
        // return the new calculated timestamp
        return _dateTime.toTimestamp(year, month, day);
    }
}
