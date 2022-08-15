//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./IERC20.sol";

interface IToken {
    function getOwner() external view returns (address);
}

contract RewardDistributor is IERC20 {

    // Token With Governance
    address public immutable token;

    // Internal Token Metrics
    string private constant _name = 'OpRise Rewards';
    string private constant _symbol = 'opBNB';
    uint8 private constant _decimals = 18;

    // User -> Share
    struct UserInfo {
        // share in MAXI
        uint256 balance;
        // excluded reward debt
        uint256 totalExcluded;
        // index in allUsers array
        uint256 index;
        // manually opt out of getting rewards
        bool hasOptedOut;
    }
    mapping ( address => UserInfo ) public userInfo;
    address[] public allUsers;

    // Tracking Info
    uint256 public totalShares;
    uint256 public totalRewards;
    uint256 private dividendsPerShare;
    uint256 private constant precision = 10**18;

    // Ownership
    modifier onlyOwner() {
        require(
            msg.sender == IToken(token).getOwner(),
            'Only Token Owner'
        );
        _;
    }
    
    modifier onlyToken() {
        require(
            msg.sender == token,
            'Only MAXI Can Call'
        );
        _;
    }

    constructor(
        address token_
    ) {
        token = token_;
    }

    event FailedToSendReward(address user, uint256 amount);

    ////////////////////////////////
    /////    TOKEN FUNCTIONS    ////
    ////////////////////////////////

    function name() external pure override returns (string memory) {
        return _name;
    }
    function symbol() external pure override returns (string memory) {
        return _symbol;
    }
    function decimals() external view override returns (uint8) {
        return _decimals;
    }
    function totalSupply() external view override returns (uint256) {
        return address(this).balance;
    }

    /** Shows The Amount Of Users' Pending Rewards */
    function balanceOf(address account) public view override returns (uint256) {
        return pendingRewards(account);
    }

    function transfer(address recipient, uint256) external override returns (bool) {
        _sendReward(recipient);
        return true;
    }
    function transferFrom(address, address recipient, uint256) external override returns (bool) {
        _sendReward(recipient);
        return true;
    }

    /** function has no use in contract */
    function allowance(address, address) external pure override returns (uint256) { 
        return 0;
    }
    /** function has no use in contract */
    function approve(address, uint256) public override returns (bool) {
        emit Approval(msg.sender, msg.sender, 0);
        return true;
    }



    ////////////////////////////////
    /////    OWNER FUNCTIONS    ////
    ////////////////////////////////

    function withdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }

    function withdrawBNB(uint256 amount) external onlyOwner {
        (bool s,) = payable(msg.sender).call{value: amount}("");
        require(s);
    }

    function setShare(address user, uint256 newShare) external onlyToken {
        if (userInfo[user].balance > 0) {
            _sendReward(user);
        }

        if (userInfo[user].balance == 0 && newShare > 0) {
            // new user
            userInfo[user].index = allUsers.length;
            allUsers.push(user);
        } else if (userInfo[user].balance > 0 && newShare == 0) {
            // user is leaving
            _removeUser(user);
        }

        // update total supply and user tracking info
        totalShares = totalShares + newShare - userInfo[user].balance;
        userInfo[user].balance = newShare;
        userInfo[user].totalExcluded = getTotalExcluded(newShare);
    }

    /////////////////////////////////
    /////   PUBLIC FUNCTIONS    /////
    /////////////////////////////////

    function donateRewards() external payable {
        _register(msg.value);
    }

    receive() external payable {
        _register(msg.value);
    }

    function massClaim() external {
        _massClaim(0, allUsers.length);
    }

    function massClaimFromIndexToIndex(uint256 startIndex, uint256 endIndex) external {
        _massClaim(startIndex, endIndex);
    }

    function claim() external {
        _sendReward(msg.sender);
    }

    function optOut() external {
        userInfo[msg.sender].hasOptedOut = true;
    }

    function optIn() external {
        userInfo[msg.sender].hasOptedOut = false;
    }

    /////////////////////////////////
    ////   INTERNAL FUNCTIONS    ////
    /////////////////////////////////


    function _sendReward(address user) internal {
        if (userInfo[user].balance == 0) {
            return;
        }

        // track pending
        uint pending = pendingRewards(user);

        // avoid overflow
        if (pending > address(this).balance) {
            pending = address(this).balance;
        }

        // update excluded earnings
        userInfo[user].totalExcluded = getTotalExcluded(userInfo[user].balance);
        
        // send reward to user
        if (pending > 0 && !userInfo[user].hasOptedOut) {
            try payable(user).transfer(pending) {} catch {
                emit FailedToSendReward(user, pending);
            }
        }
    }

    function _register(uint256 amount) internal {

        // Increment Total Rewards
        totalRewards += amount;

        // Add Dividends Per Share
        if (totalShares > 0) {
            dividendsPerShare += ( precision * amount ) / totalShares;
        }
    }

    function _removeUser(address user) internal {

        // index to replace
        uint256 replaceIndex = userInfo[user].index;
        if (allUsers[replaceIndex] != user) {
            return;
        }

        // last user in array
        address lastUser = allUsers[allUsers.length - 1];

        // set last user's index to the replace index
        userInfo[lastUser].index = replaceIndex;

        // set replace index in array to last user
        allUsers[replaceIndex] = lastUser;

        // pop last user off the end of the array
        allUsers.pop();
        delete userInfo[user].index;
    }

    function _massClaim(uint256 startIndex, uint256 endIndex) internal {
        require(
            endIndex <= allUsers.length,
            'End Length Too Large'
        );

        for (uint i = startIndex; i < endIndex;) {
            _sendReward(allUsers[i]);
            unchecked { ++i; }
        }
    }

    ////////////////////////////////
    /////    READ FUNCTIONS    /////
    ////////////////////////////////

    function pendingRewards(address user) public view returns (uint256) {
        if(userInfo[user].balance == 0){ return 0; }

        uint256 userTotalExcluded = getTotalExcluded(userInfo[user].balance);
        uint256 userTrackedExcluded = userInfo[user].totalExcluded;

        if(userTotalExcluded <= userTrackedExcluded){ return 0; }

        return userTotalExcluded - userTrackedExcluded;
    }

    function getTotalExcluded(uint256 amount) public view returns (uint256) {
        return ( amount * dividendsPerShare ) / precision;
    }

    function viewAllUsers() external view returns (address[] memory) {
        return allUsers;
    }

    function holderCount() external view returns (uint256) {
        return allUsers.length;
    }
}