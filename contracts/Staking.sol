// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


error Staking_TransferFailed();
error Staking_NeedsMoreThanZero();

contract Staking {
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    // user adress -> how much they staked
    mapping(address => uint256) public balances;
    // user address -> how much has been paid
    mapping(address => uint256) public userRewardPerTokenPaid;
    // user address -> rewards earned
    mapping(address => uint256) public rewards;

    uint256 public totalSupply;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public constant REWARD_RATE = 100;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    modifier updateReward(address account) {
        // how much reward per token?
        //  R = 100 tokens/second
        //  L = 100 token: 1 token / staked token
        //  L = 200 token: 0.5 token / staked token
       
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert Staking_NeedsMoreThanZero();
        }
        _;
    }

    function earned(address account) public view returns(uint256) {
        uint256 currentBalance = balances[account];
        // how much they have been paid already
        uint256 amountPaid = userRewardPerTokenPaid[account];
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 pastRewards = rewards[account];

        uint256 _earned = ((currentBalance * (currentRewardPerToken - amountPaid))/1e18) + pastRewards;
        return _earned;
    }

    // based on how long it's been during this most recent snapshot
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        } 

        return rewardPerTokenStored + (((block.timestamp - lastUpdateTime) * REWARD_RATE * 1e18) / totalSupply);
    }
    
    // keep track of how nuch this user has staked
    // keep track of how much token we have in total
    // transfer token to this contract
    function stake(uint256 amount) updateReward(msg.sender) moreThanZero(amount) external {
        balances[msg.sender] += amount;
        totalSupply += amount;
        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert Staking_TransferFailed();
        }
    }

    function withdraw(uint256 amount) updateReward(msg.sender)  moreThanZero(amount) external {
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        bool success = stakingToken.transfer(msg.sender, amount);
        if (!success) {
            revert Staking_TransferFailed();
        }
    }

    // the contract is going to emit x tokens per second
    // and disperese them to all token stakers
    function claimReward() updateReward(msg.sender) external {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        bool success = rewardToken.transfer(msg.sender, reward);
        if(!success) {
            revert Staking_TransferFailed();
        }
    }
}