// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IEconomicModel.sol";

/**
 * @title ProgressTracker
 * @dev 学习进度追踪库
 * @notice 管理学生的课程学习进度，用于退款资格判断
 */
library ProgressTracker {

    // ==================== 常量定义 ====================

    uint256 constant REFUND_THRESHOLD = 30; // 退款阈值：学习进度低于30%可退款

    // ==================== 错误定义 ====================

    error InvalidProgress();
    error ProgressExceedsTotal();
    error CourseNotStarted();

    // ==================== 核心功能 ====================

    /**
     * @dev 初始化课程进度
     * @param progressData 进度数据映射
     * @param student 学生地址
     * @param courseId 课程ID
     * @param totalLessons 课程总课时数
     */
    function initializeProgress(
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256 courseId,
        uint256 totalLessons
    ) internal {
        require(totalLessons > 0, "Total lessons must be greater than 0");

        progressData[student][courseId] = IEconomicModel.LearningProgress({
            courseId: courseId,
            completedLessons: 0,
            totalLessons: totalLessons,
            progressPercent: 0,
            lastUpdateTime: block.timestamp
        });
    }

    /**
     * @dev 更新学习进度
     * @param progressData 进度数据映射
     * @param student 学生地址
     * @param courseId 课程ID
     * @param completedLessons 已完成课时数
     */
    function updateProgress(
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256 courseId,
        uint256 completedLessons
    ) internal {
        IEconomicModel.LearningProgress storage progress = progressData[student][courseId];

        // 验证课程是否已开始
        if (progress.totalLessons == 0) {
            revert CourseNotStarted();
        }

        // 验证进度是否合法
        if (completedLessons > progress.totalLessons) {
            revert ProgressExceedsTotal();
        }

        // 更新进度
        progress.completedLessons = completedLessons;
        progress.progressPercent = calculateProgressPercent(
            completedLessons,
            progress.totalLessons
        );
        progress.lastUpdateTime = block.timestamp;
    }

    /**
     * @dev 检查是否符合退款条件
     * @param progressData 进度数据映射
     * @param student 学生地址
     * @param courseId 课程ID
     * @return 是否可以退款
     */
    function isRefundEligible(
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256 courseId
    ) internal view returns (bool) {
        IEconomicModel.LearningProgress storage progress = progressData[student][courseId];

        // 进度小于30%才能退款
        return progress.progressPercent < REFUND_THRESHOLD;
    }

    /**
     * @dev 获取学习进度
     * @param progressData 进度数据映射
     * @param student 学生地址
     * @param courseId 课程ID
     * @return 学习进度信息
     */
    function getProgress(
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256 courseId
    ) internal view returns (IEconomicModel.LearningProgress memory) {
        return progressData[student][courseId];
    }

    /**
     * @dev 批量获取学习进度
     * @param progressData 进度数据映射
     * @param student 学生地址
     * @param courseIds 课程ID数组
     * @return 进度信息数组
     */
    function batchGetProgress(
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256[] memory courseIds
    ) internal view returns (IEconomicModel.LearningProgress[] memory) {
        IEconomicModel.LearningProgress[] memory results =
                    new IEconomicModel.LearningProgress[](courseIds.length);

        for (uint256 i = 0; i < courseIds.length; i++) {
            results[i] = progressData[student][courseIds[i]];
        }

        return results;
    }

    // ==================== 辅助计算函数 ====================

    /**
     * @dev 计算进度百分比
     * @param completed 已完成数量
     * @param total 总数量
     * @return 百分比（0-100）
     */
    function calculateProgressPercent(uint256 completed, uint256 total)
    internal
    pure
    returns (uint256)
    {
        if (total == 0) return 0;
        return (completed * 100) / total;
    }

    /**
     * @dev 检查进度是否已完成
     * @param progressData 进度数据映射
     * @param student 学生地址
     * @param courseId 课程ID
     * @return 是否已完成
     */
    function isCompleted(
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256 courseId
    ) internal view returns (bool) {
        IEconomicModel.LearningProgress storage progress = progressData[student][courseId];
        return progress.progressPercent >= 100;
    }

    /**
     * @dev 获取剩余课时数
     * @param progressData 进度数据映射
     * @param student 学生地址
     * @param courseId 课程ID
     * @return 剩余课时数
     */
    function getRemainingLessons(
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData,
        address student,
        uint256 courseId
    ) internal view returns (uint256) {
        IEconomicModel.LearningProgress storage progress = progressData[student][courseId];
        return progress.totalLessons - progress.completedLessons;
    }

    /**
     * @dev 获取退款阈值
     * @return 退款阈值百分比
     */
    function getRefundThreshold() internal pure returns (uint256) {
        return REFUND_THRESHOLD;
    }
}