# Payroll
Payroll smart contract.
## Interface
```
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
```
## Intreface modification
- addEmployee takes as an input an intial token distribution.
- getEmployee returns the employee's address, yearly salary, last distribution update and last day day update.
- Use ERC223 tokenFallback.
## Smart Contract Reference
- [DateTime contract](https://github.com/pipermerriam/ethereum-datetime)
- [OpenZeppelin Ownable contract](https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/ownership/Ownable.sol)
- [EIP20](https://github.com/ConsenSys/Tokens/blob/master/contracts/eip20/EIP20.sol)
## TO DO
- [ ] Write unit test
