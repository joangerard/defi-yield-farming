// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./DappToken.sol";
import "./LPToken.sol";

contract TokenFarm {
    string public name = "Proportional Token Farm";
    address public owner;
    DappToken public dappToken;
    LPToken public lpToken;
    uint256 public constant REWARD_PER_BLOCK = 1e18;
    uint256 public totalStakingBalance;
    address[] public stakers;

    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public checkpoints;
    mapping(address => uint256) public pendingRewards;
    mapping(address => bool) public hasStaked;
    mapping(address => bool) public isStaking;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDistributed();

    constructor(DappToken _dappToken, LPToken _lpToken) {
        owner = msg.sender;
        dappToken = _dappToken;
        lpToken = _lpToken;
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Deposit amount must be > 0");

        // Transferir tokens LP
        lpToken.transferFrom(msg.sender, address(this), _amount);

        // Inicializar checkpoint si es primera vez
        if (checkpoints[msg.sender] == 0) {
            checkpoints[msg.sender] = block.number;
        }

        // Actualizar balance
        stakingBalance[msg.sender] += _amount;
        totalStakingBalance += _amount;

        // Stakers array
        if (!hasStaked[msg.sender]) {
            stakers.push(msg.sender);
            hasStaked[msg.sender] = true;
        }

        isStaking[msg.sender] = true;

        emit Deposit(msg.sender, _amount);
    }

    function withdraw() external {
        require(isStaking[msg.sender], "You don't have staking");
        uint256 balance = stakingBalance[msg.sender];
        require(balance > 0, "No staking balance");

        distributeRewards(msg.sender);

        stakingBalance[msg.sender] = 0;
        totalStakingBalance -= balance;
        isStaking[msg.sender] = false;

        lpToken.transfer(msg.sender, balance);

        emit Withdraw(msg.sender, balance);
    }

    function claimRewards() external {
        uint256 pendingAmount = pendingRewards[msg.sender];
        require(pendingAmount > 0, "Pending rewards must be greater than 0");

        pendingRewards[msg.sender] = 0;
        dappToken.mint(msg.sender, pendingAmount);

        emit RewardsClaimed(msg.sender, pendingAmount);
    }

    function distributeRewardsAll() external {
        require(msg.sender == owner, "Only owner");

        for (uint i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            if (isStaking[staker]) {
                distributeRewards(staker);
            }
        }

        emit RewardsDistributed();
    }

    function distributeRewards(address beneficiary) private {
        uint256 lastCheckpoint = checkpoints[beneficiary];
        if (
            lastCheckpoint == 0 ||
            block.number <= lastCheckpoint ||
            totalStakingBalance == 0
        ) {
            return;
        }

        uint256 blocksPassed = block.number - lastCheckpoint;
        uint256 share = (stakingBalance[beneficiary] * 1e18) /
            totalStakingBalance;
        uint256 reward = (REWARD_PER_BLOCK * blocksPassed * share) / 1e18;

        pendingRewards[beneficiary] += reward;
        checkpoints[beneficiary] = block.number;
    }
}
