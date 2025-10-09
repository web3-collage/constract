// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";
import "../interfaces/IEconomicModel.sol";

/**
 * @title WithdrawalLogic
 * @dev 提现逻辑库
 */
library WithdrawalLogic {

    error InsufficientEarnings();
    error CooldownActive();
    error TransferFailed();

    // 事件定义
    event EarningsRecorded(address indexed instructor, uint256 amount, uint256 totalEarned, uint256 pending);
    event EarningsDeducted(address indexed instructor, uint256 amount, uint256 totalEarned, uint256 pending);

    /**
     * @dev 执行提现
     * @notice Gas优化：使用unchecked避免溢出检查
     */
    function executeWithdrawal(
        IERC20 token,
        mapping(address => IEconomicModel.InstructorEarnings) storage instructorEarnings,
        mapping(address => uint256[]) storage withdrawalHistory,
        mapping(address => uint256) storage lastWithdrawalTime,
        address instructor,
        uint256 minWithdrawalAmount,
        uint256 withdrawalCooldown
    ) internal returns (uint256 amount) {
        // 检查条件
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];
        if (earnings.pending < minWithdrawalAmount) revert InsufficientEarnings();
        if (block.timestamp < lastWithdrawalTime[instructor] + withdrawalCooldown) revert CooldownActive();

        // 更新状态
        amount = earnings.pending;

        // Gas优化：withdrawn只会增加，不会溢出
        unchecked {
            earnings.withdrawn += amount;
        }

        earnings.pending = 0;
        withdrawalHistory[instructor].push(block.timestamp);
        lastWithdrawalTime[instructor] = block.timestamp;

        // 转账
        if (!token.transfer(instructor, amount)) revert TransferFailed();
    }

    /**
     * @dev 记录收益
     * @notice Gas优化：使用unchecked，收益只会累加
     */
    function recordEarnings(
        mapping(address => IEconomicModel.InstructorEarnings) storage instructorEarnings,
        address instructor,
        uint256 amount
    ) internal {
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        // Gas优化：totalEarned和pending只会增加，不会溢出
        unchecked {
            earnings.totalEarned += amount;
            earnings.pending += amount;
        }

        // 添加事件记录
        emit EarningsRecorded(instructor, amount, earnings.totalEarned, earnings.pending);
    }

    /**
     * @dev 扣除讲师收益（用于退款）
     * @notice 修复：退款时需要扣除讲师的pending余额
     * @notice 如果讲师已经部分提现，退款将失败（保护讲师已提现的资金）
     */
    function deductEarnings(
        mapping(address => IEconomicModel.InstructorEarnings) storage instructorEarnings,
        address instructor,
        uint256 amount
    ) internal {
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        // 修复：检查pending是否足够
        // 如果讲师已经提现了部分资金，pending会不足，此时应该拒绝退款
        require(earnings.pending >= amount, "Instructor already withdrawn, cannot refund");

        // 只有在totalEarned也足够的情况下才能扣除
        require(earnings.totalEarned >= amount, "Insufficient total earnings");

        // 同时减少totalEarned和pending
        earnings.totalEarned -= amount;
        earnings.pending -= amount;

        // 添加事件记录
        emit EarningsDeducted(instructor, amount, earnings.totalEarned, earnings.pending);
    }
}
