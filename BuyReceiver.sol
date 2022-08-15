//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IERC20.sol";

interface IOpRise {
    function getOwner() external view returns (address);
    function burn(uint256 amount) external returns (bool);
}

contract TaxReceiver {

    // token
    address public immutable token;

    // Recipients Of Fees
    address public reliefFund;
    address public marketing;

    // Trust Fund Allocation
    uint256 public reliefFundPercentage;
    uint256 public marketingPercentage;
    uint256 public percentageDenom;

    // Bounty Percent
    uint256 public bountyPercent = 20; // 2%

    modifier onlyOwner(){
        require(
            msg.sender == IOpRise(token).getOwner(),
            'Only MDB Owner'
        );
        _;
    }

    constructor(address token_, address reliefFund_, address marketing_) {
        require(
            token_ != address(0) &&
            reliefFund_ != address(0) &&
            marketing_ != address(0),
            'Zero Address'
        );

        // Initialize Addresses
        token = token_;
        reliefFund = reliefFund_;
        marketing = marketing_;

        // trust fund percentage
        reliefFundPercentage = 5;
        marketingPercentage  = 2;
        percentageDenom      = 15;
    }

    function trigger() external {

        // get bounty and send to caller
        uint bounty = currentBounty();
        if (bounty > 0) {
            _send(msg.sender, bounty);
        }

        // Balance In Contract
        uint balance = balanceOf();

        // fraction out tokens
        uint rFund = balance * reliefFundPercentage / percentageDenom;
        uint mFund = balance * marketingPercentage / percentageDenom;

        // send to destinations
        _send(reliefFund, rFund);
        _send(marketing, mFund);

        // burn rest
        balance = balanceOf();
        if (balance > 0) {
            IOpRise(token).burn(balance);
        }
    }

    function setReliefFund(address tFund) external onlyOwner {
        require(tFund != address(0));
        reliefFund = tFund;
    }
    
    function setMarketing(address marketing_) external onlyOwner {
        require(marketing_ != address(0));
        marketing = marketing_;
    }

    function setBountyPercent(uint256 newBounty) external onlyOwner {
        require(newBounty <= 500);
        bountyPercent = newBounty;
    }
   
    function setPercentages(uint256 reliefFundPercent, uint256 marketingPercent, uint256 burnPercent) external onlyOwner {
        reliefFundPercentage = reliefFundPercent;
        marketingPercentage = marketingPercent;
        percentageDenom = reliefFundPercent + marketingPercent + burnPercent;
    }
    
    function withdraw() external onlyOwner {
        (bool s,) = payable(msg.sender).call{value: address(this).balance}("");
        require(s);
    }
    
    function withdraw(address _token) external onlyOwner {
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }
    
    receive() external payable {}

    function _send(address recipient, uint amount) internal {
        bool s = IERC20(token).transfer(recipient, amount);
        require(s, 'Failure On Token Transfer');
    }

    function balanceOf() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function currentBounty() public view returns (uint256) {
        return ( balanceOf() * bountyPercent ) / 1000;
    }
}