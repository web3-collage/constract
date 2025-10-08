// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IEconomicModel.sol";
import "../interfaces/IERC20.sol";

/**
 * @title WithdrawalModule
 * @dev 提现管理模块
 * @notice 管理讲师的收益记录和提现操作
 */
contract WithdrawalModule {

    // ==================== 状态变量 ====================

    IERC20 public ydToken;  // YD代币合约引用

    mapping(address => IEconomicModel.InstructorEarnings) public instructorEarnings; // 讲师收益
    mapping(address => uint256[]) public withdrawalHistory;  // 提现历史（时间戳数组）
    mapping(address => uint256) public lastWithdrawalTime;   // 最后提现时间

    uint256 public minWithdrawalAmount = 10 * 1e18;  // 最小提现金额：10 YD
    uint256 public withdrawalCooldown = 1 days;      // 提现冷却时间：1天

    // ==================== 事件定义 ====================

    event InstructorWithdrawal(
        address indexed instructor,
        uint256 amount,
        uint256 timestamp
    );

    event EarningsUpdated(
        address indexed instructor,
        uint256 totalEarned,
        uint256 pending
    );

    event MinWithdrawalAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event WithdrawalCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    // ==================== 构造函数 ====================

    constructor(address _ydToken) {
        require(_ydToken != address(0), "Invalid YD token address");
        ydToken = IERC20(_ydToken);
    }

    // ==================== 修饰符 ====================

    /**
     * @dev 验证有足够的待提现金额
     */
    modifier hasPendingEarnings(address instructor) {
        require(
            instructorEarnings[instructor].pending >= minWithdrawalAmount,
            "Insufficient pending earnings"
        );
        _;
    }

    /**
     * @dev 验证提现冷却时间
     */
    modifier cooldownPassed(address instructor) {
        require(
            block.timestamp >= lastWithdrawalTime[instructor] + withdrawalCooldown,
            "Withdrawal cooldown not passed"
        );
        _;
    }

    // ==================== 核心功能 ====================

    /**
     * @dev 记录讲师收益（内部调用）
     * @param instructor 讲师地址
     * @param amount 收益金额
     */
    function _recordEarnings(address instructor, uint256 amount) internal {
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        earnings.totalEarned += amount;
        earnings.pending += amount;

        emit EarningsUpdated(instructor, earnings.totalEarned, earnings.pending);
    }

    /**
     * @dev 讲师提现
     * @return amount 提现金额
     */
    function withdrawEarnings()
    external
    virtual
    hasPendingEarnings(msg.sender)
    cooldownPassed(msg.sender)
    returns (uint256 amount)
    {
        address instructor = msg.sender;
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        amount = earnings.pending;

        // 更新收益记录
        earnings.withdrawn += amount;
        earnings.pending = 0;

        // 记录提现历史
        withdrawalHistory[instructor].push(block.timestamp);
        lastWithdrawalTime[instructor] = block.timestamp;

        // 转账YD代币
        require(
            ydToken.transfer(instructor, amount),
            "YD transfer failed"
        );

        emit InstructorWithdrawal(instructor, amount, block.timestamp);
        return amount;
    }

    // ==================== 查询功能 ====================

    /**
     * @dev 获取讲师收益信息
     * @param instructor 讲师地址
     * @return 收益信息结构体
     */
    function getInstructorEarnings(address instructor)
    external
    view
    virtual
    returns (IEconomicModel.InstructorEarnings memory)
    {
        return instructorEarnings[instructor];
    }

    /**
     * @dev 获取讲师待提现金额
     * @param instructor 讲师地址
     * @return 待提现金额
     */
    function getPendingEarnings(address instructor)
    external
    view
    returns (uint256)
    {
        return instructorEarnings[instructor].pending;
    }

    /**
     * @dev 获取讲师总收益
     * @param instructor 讲师地址
     * @return 总收益金额
     */
    function getTotalEarned(address instructor)
    external
    view
    returns (uint256)
    {
        return instructorEarnings[instructor].totalEarned;
    }

    /**
     * @dev 获取讲师已提现金额
     * @param instructor 讲师地址
     * @return 已提现金额
     */
    function getWithdrawn(address instructor)
    external
    view
    returns (uint256)
    {
        return instructorEarnings[instructor].withdrawn;
    }

    /**
     * @dev 获取提现历史
     * @param instructor 讲师地址
     * @return 提现时间戳数组
     */
    function getWithdrawalHistory(address instructor)
    external
    view
    returns (uint256[] memory)
    {
        return withdrawalHistory[instructor];
    }

    /**
     * @dev 检查是否可以提现
     * @param instructor 讲师地址
     * @return canWithdraw 是否可以提现
     * @return reason 不能提现的原因（空字符串表示可以提现）
     */
    function canWithdraw(address instructor)
    external
    view
    returns (bool, string memory reason)
    {
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        if (earnings.pending < minWithdrawalAmount) {
            return (false, "Insufficient pending earnings");
        }

        if (block.timestamp < lastWithdrawalTime[instructor] + withdrawalCooldown) {
            return (false, "Withdrawal cooldown not passed");
        }

        return (true, "");
    }
}