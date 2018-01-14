pragma solidity ^0.4.11;

contract Loaning {

    address public buyer;
    uint public loanRequestAmount;
    uint public totalAmountLoaned;
    uint public interestRate;
    uint public moneyToRepay;
    uint public priceOfProperty;
    // ERC20 public Token;

    mapping(address => uint256) public balanceOf;

    mapping(address => uint256) public ownerships;
    uint totalSupply;
    uint totalDividends;
    uint decimals;

    mapping(address => bool) public claimedCurrentLoanRecord;
    bool loanFilled = false;
    bool loanClosed = false;
    uint twoMonthTimer;

    event LoanFilled(address recipient, uint totalAmountLoaned);
    event FundTransfer(address loaner, uint amount, bool isLoan);
    event OwnershipTransfer(address newOwner, uint amount);

    /**
    * Constructor function
    *
    * Buyer is set as owner
     */
    function Loaning(
        uint propertyValue,
        uint requestedAmount
    ) {
        buyer = msg.sender;
        priceOfProperty = propertyValue * 1 wei;
        loanRequestAmount = requestedAmount * 1 wei;
        totalSupply = 100;
        ownerships[buyer] += calcOwnership(priceOfProperty - loanRequestAmount);
    }

    /**
    * Fallback function to call whenever anyone sends funds
     */
    function () payable public{
        require(!loanClosed);
        uint amount = msg.value * 1 wei;
        require(amount <= loanRequestAmount);
        balanceOf[msg.sender] += amount;
        totalAmountLoaned += amount;
        ownerships[msg.sender] = calcOwnership(amount);
        loanRequestAmount -= amount;
        FundTransfer(msg.sender, amount, true);
        claimedCurrentLoanRecord[msg.sender] = false;
    }

    /**
    * Provides buyer an option to close the loan
     */
    function closeLoan() external {
        require(msg.sender==buyer);
        loanFilled = false;
    }

    /**
    * Check if goal was reached
    * Checks if the goal or time limit has been reached and ends the campaign
     */
     function checkGoalReached() {
         if (totalAmountLoaned == loanRequestAmount) {
             loanFilled = true;
             LoanFilled(buyer, totalAmountLoaned);
         }
     }

     /**
     * Withdraw the funds
     * Checks to see if loanRequestAmount or time limit has been reached, and if so, and the funding goal was reached,
     * sends the entire amount to the buyer.  If the loanRequestAmount was not reached, each contributor can withdraw
     * the amount they contributed.
      */
    function safeWithdrawal() {
        if (!loanFilled) {
            uint amount = balanceOf[msg.sender];
            balanceOf[msg.sender] = 0;
            if (amount > 0) {
                if (msg.sender.send(amount)) {
                    FundTransfer(msg.sender, amount, false);
                } else {
                    balanceOf[msg.sender] = amount;
                }
            }
        }

        if (loanFilled && buyer == msg.sender) {
            if (buyer.send(totalAmountLoaned)) {
                twoMonthTimer = now + 8 weeks;
                moneyToRepay = totalAmountLoaned;
                FundTransfer(buyer, totalAmountLoaned, false);
            } else {
                //If we fail to send the funds to the buyer, unlock loaners balance
                loanFilled = false;
            }
        }
    }
    
    /**
     * Determines whether payment of 10% of remaining loan due was paid every two months
     */
    modifier afterTwoMonthDeadline() { if (now >= twoMonthTimer) _; }
    modifier beforeTwoMonthDeadline() { if (now < twoMonthTimer) _; }

    
    function paybackLoan(uint amount) payable public beforeTwoMonthDeadline returns (bool success) {
        amount *= 1 wei;
        require(amount >= moneyToRepay / 10);
        twoMonthTimer = now + 8 weeks;
    }
    
    function claimLoan() public beforeTwoMonthDeadline returns (bool uccess) {
        return true;
    }

    /**
     * Calculates ownership stake based on original price of propertyValue
     */
    function calcOwnership(uint payment) public returns (uint256) {
        return payment * 1 ether / priceOfProperty;
    }
    
    /**
     * Transfers ownership from old owner to new
     * Sets old owner's ownership stake to 0
     */
    function transferOwnership(address _to) public returns (bool success) {
        uint256 oldOwnership = ownerships[msg.sender];
        ownerships[msg.sender] = 0;
        ownerships[_to] = oldOwnership;
        OwnershipTransfer(msg.sender, oldOwnership);
        return true;
    }

    /**
     * Allows for purchasing of ownership from a loaner if a loan defaults.
     */
    function purchaseLoanerOwnership(address ownershipOwner, uint256 amount) payable public returns (bool success) {
      uint256 ownershipWorth = ownerships[ownershipOwner] * priceOfProperty;
      amount *= 1 wei;
      require(msg.sender.balance >= amount);
      if (transferOwnership(msg.sender) && amount == ownershipWorth) {
          ownershipOwner.transfer(amount);
          return true;
      }
    } 
    
    /**
     * Reorganize ownership percentages
     * Checks to see if the buyer paid 10% of remaining loan due was paid in the past two months
     * If yes, then the assets stay put and false returns
     * If no, buyer assets are set to 0, buyer's assets are distributed accordingly to the claimer's owning percentage
     */
    function claimAllAssets() public afterTwoMonthDeadline returns (bool success) {
        uint256 buyerOwnership = ownerships[buyer];
        uint256 claimerOwnership = ownerships[msg.sender];
        uint256 addedOwnership = (buyerOwnership / 1 ether) * claimerOwnership;
        ownerships[msg.sender] += addedOwnership;
        OwnershipTransfer(msg.sender, addedOwnership);
        return true;
    }
}