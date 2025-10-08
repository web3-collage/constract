// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";

/**
 * @title SimpleYDToken
 * @dev YD代币合约（包含质押挖矿功能）
 */
contract SimpleYDToken is IERC20 {

    // ==================== 基础代币变量 ====================

    uint256 public constant EXCHANGE_RATE = 4000;
    string public constant name = "Yideng Token";
    string public constant symbol = "YD";
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    address public owner;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ==================== 质押挖矿变量 ====================

    struct StakeInfo {
        uint256 amount;          // 质押金额
        uint256 startTime;       // 质押开始时间
        uint256 lockPeriod;      // 锁定期（秒）
        uint256 rewardRate;      // 年化收益率（基点，10000 = 100%）
        uint256 lastClaimTime;   // 上次领取收益时间
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;                    // 总质押量
    uint256 public constant MIN_STAKE_AMOUNT = 100 * 1e18;  // 最小质押：100 YD
    uint256 public constant EARLY_UNLOCK_PENALTY = 2000;     // 提前解锁惩罚：20%

    // 质押套餐配置
    uint256 public constant LOCK_30_DAYS = 30 days;
    uint256 public constant LOCK_90_DAYS = 90 days;
    uint256 public constant LOCK_180_DAYS = 180 days;

    uint256 public constant RATE_30_DAYS = 500;    // 5% APY
    uint256 public constant RATE_90_DAYS = 1000;   // 10% APY
    uint256 public constant RATE_180_DAYS = 2000;  // 20% APY

    // ==================== 事件定义 ====================

    event Staked(address indexed user, uint256 amount, uint256 lockPeriod, uint256 rewardRate);
    event Unstaked(address indexed user, uint256 amount, uint256 reward, bool earlyUnlock);
    event RewardClaimed(address indexed user, uint256 reward);

    // ==================== 修饰符 ====================

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier hasStake() {
        require(stakes[msg.sender].amount > 0, "No active stake");
        _;
    }

    modifier noActiveStake() {
        require(stakes[msg.sender].amount == 0, "Active stake exists");
        _;
    }

    // ==================== 构造函数 ====================

    constructor() {
        owner = msg.sender;
        _totalSupply = 1000000 * 10**decimals;
        _balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }

    // ==================== ERC20标准功能 ====================

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address ownerAddr, address spender) public view override returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // ==================== ETH兑换YD ====================

    function exchangeETHForTokens() external payable {
        require(msg.value > 0, "Must send ETH to exchange");
        uint256 tokenAmount = msg.value * EXCHANGE_RATE;
        _transfer(owner, msg.sender, tokenAmount);
    }

    // ==================== 质押挖矿功能 ====================

    /**
     * @dev 质押YD代币
     * @param amount 质押数量
     * @param lockPeriod 锁定期（30/90/180天）
     */
    function stake(uint256 amount, uint256 lockPeriod) external noActiveStake {
        require(amount >= MIN_STAKE_AMOUNT, "Amount below minimum stake");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        uint256 rewardRate = _getRewardRate(lockPeriod);
        require(rewardRate > 0, "Invalid lock period");

        _balances[msg.sender] -= amount;
        totalStaked += amount;

        stakes[msg.sender] = StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            lockPeriod: lockPeriod,
            rewardRate: rewardRate,
            lastClaimTime: block.timestamp
        });

        emit Staked(msg.sender, amount, lockPeriod, rewardRate);
    }

    /**
     * @dev 解除质押
     * @param forceUnlock 是否强制解锁（会扣除20%惩罚）
     */
    function unstake(bool forceUnlock) external hasStake {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 stakedAmount = stakeInfo.amount;
        bool isEarlyUnlock = block.timestamp < stakeInfo.startTime + stakeInfo.lockPeriod;

        require(forceUnlock || !isEarlyUnlock, "Lock period not ended");

        uint256 reward = _calculateReward(msg.sender);
        uint256 totalReturn = stakedAmount + reward;

        if (isEarlyUnlock && forceUnlock) {
            uint256 penalty = (stakedAmount * EARLY_UNLOCK_PENALTY) / 10000;
            totalReturn = stakedAmount - penalty + reward;
            _balances[owner] += penalty;
        }

        _balances[msg.sender] += totalReturn;
        totalStaked -= stakedAmount;

        emit Unstaked(msg.sender, stakedAmount, reward, isEarlyUnlock);

        delete stakes[msg.sender];
    }

    /**
     * @dev 领取质押收益（不解除质押）
     */
    function claimReward() external hasStake {
        uint256 reward = _calculateReward(msg.sender);
        require(reward > 0, "No reward to claim");

        stakes[msg.sender].lastClaimTime = block.timestamp;
        _mint(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    // ==================== 查询功能 ====================

    function getStakeInfo(address user) external view returns (StakeInfo memory) {
        return stakes[user];
    }

    function calculatePendingReward(address user) external view returns (uint256) {
        if (stakes[user].amount == 0) return 0;
        return _calculateReward(user);
    }

    function canUnstake(address user) external view returns (bool) {
        if (stakes[user].amount == 0) return false;
        return block.timestamp >= stakes[user].startTime + stakes[user].lockPeriod;
    }

    // ==================== 内部函数 ====================

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address ownerAddr, address spender, uint256 amount) internal {
        require(ownerAddr != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    function _spendAllowance(address ownerAddr, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(ownerAddr, spender);
        require(currentAllowance >= amount, "Insufficient allowance");
        _approve(ownerAddr, spender, currentAllowance - amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Mint to zero address");
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _calculateReward(address user) internal view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user];
        uint256 timeElapsed = block.timestamp - stakeInfo.lastClaimTime;
        uint256 reward = (stakeInfo.amount * stakeInfo.rewardRate * timeElapsed) / (10000 * 365 days);
        return reward;
    }

    function _getRewardRate(uint256 lockPeriod) internal pure returns (uint256) {
        if (lockPeriod == LOCK_30_DAYS) return RATE_30_DAYS;
        if (lockPeriod == LOCK_90_DAYS) return RATE_90_DAYS;
        if (lockPeriod == LOCK_180_DAYS) return RATE_180_DAYS;
        return 0;
    }

    // ==================== 管理员功能 ====================

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function batchTransfer(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}