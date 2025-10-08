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

    /**
     * @dev 执行提现
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
        earnings.withdrawn += amount;
        earnings.pending = 0;
        withdrawalHistory[instructor].push(block.timestamp);
        lastWithdrawalTime[instructor] = block.timestamp;

        // 转账
        if (!token.transfer(instructor, amount)) revert TransferFailed();
    }

    /**
     * @dev 记录收益
     */
    function recordEarnings(
        mapping(address => IEconomicModel.InstructorEarnings) storage instructorEarnings,
        address instructor,
        uint256 amount
    ) internal {
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];
        earnings.totalEarned += amount;
        earnings.pending += amount;
    }
}
