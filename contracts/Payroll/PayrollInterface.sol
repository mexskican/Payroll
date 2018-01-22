pragma solidity ^0.4.18;

contract PayrollInterface {
    /* OWNER ONLY */
    function addEmployee(address accountAddress, address[] allowedTokens, uint256[] initialDistribution, uint256 initialYearlyEURSalary);
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary);
    function removeEmployee(uint256 employeeId);

    function addFunds() payable;
    function escapeHatch();
    function tokenFallback(address from, uint value, bytes data);

    function getEmployeeCount() constant returns (uint256);
    function getEmployee(uint256 employeeId) constant returns (address employee, uint256 yearlyEURSalary, uint256 lastDistributionUpdate, uint256 lastPayDay);

    function calculatePayrollBurnrate() constant returns (uint256);
    function calculatePayrollRunway() constant returns (uint256);

    /* EMPLOYEE ONLY */
    function determineAllocation(address[] tokens, uint256[] distribution);
    function payday();

    /* ORACLE ONLY */
    function setExchangeRate(address token, uint256 EURExchangeRate);
}
