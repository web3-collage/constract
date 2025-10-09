// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IEconomicModel.sol";
import "./ProgressTracker.sol";

/**
 * @title RefundLogic
 * @dev 退款逻辑库
 */
library RefundLogic {

    error RefundWindowExpired();

    /**
     * @dev 验证退款资格
     */
    function validateRefundEligibility(
        mapping(address => mapping(uint256 => uint256)) storage purchaseTimestamps,
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256 courseId,
        uint256 refundWindow
    ) internal view {
        // 检查时间窗口
        uint256 purchaseTime = purchaseTimestamps[student][courseId];
        if (block.timestamp > purchaseTime + refundWindow) revert RefundWindowExpired();

        // 检查学习进度
        if (!ProgressTracker.isRefundEligible(progressData, student, courseId)) {
            revert ProgressTracker.ProgressExceedsTotal();
        }
    }


    /**
     * @dev 检查是否可以退款
     */
    function checkRefundability(
        mapping(address => mapping(uint256 => bool)) storage hasPurchased,
        mapping(address => mapping(uint256 => bool)) storage hasRefunded,
        mapping(address => mapping(uint256 => uint256)) storage purchaseTimestamps,
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256 courseId,
        uint256 refundWindow
    ) internal view returns (bool canRefundNow, string memory reason) {
        if (!hasPurchased[student][courseId]) {
            return (false, "Not purchased");
        }

        if (hasRefunded[student][courseId]) {
            return (false, "Already refunded");
        }

        uint256 purchaseTime = purchaseTimestamps[student][courseId];
        if (block.timestamp > purchaseTime + refundWindow) {
            return (false, "Window expired");
        }

        if (!ProgressTracker.isRefundEligible(progressData, student, courseId)) {
            return (false, "Progress >30%");
        }

        return (true, "");
    }
}
