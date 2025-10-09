// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEconomicModel
 * @dev 经济模型相关接口定义
 */
interface IEconomicModel {

    // ==================== 数据结构 ====================

    /**
     * @dev 讲师收益信息
     */
    struct InstructorEarnings {
        uint256 totalEarned;      // 总收益
        uint256 withdrawn;        // 已提现
        uint256 pending;          // 待提现
    }

    /**
     * @dev 学习进度信息
     */
    struct LearningProgress {
        uint256 courseId;         // 课程ID
        uint256 completedLessons; // 已完成课时
        uint256 totalLessons;     // 总课时数
        uint256 progressPercent;  // 完成百分比
        uint256 lastUpdateTime;   // 最后更新时间
    }

    /**
     * @dev 退款申请信息
     */
    struct RefundRequest {
        uint256 courseId;         // 课程ID
        address student;          // 学生地址
        uint256 refundAmount;     // 退款金额
        uint256 requestTime;      // 申请时间
        bool processed;           // 是否已处理
        bool approved;            // 是否批准
    }

    /**
     * @dev 分账配置
     */
    struct FeeConfig {
        uint256 instructorRate;   // 讲师分成比例 (默认90%)
        uint256 platformRate;     // 平台分成比例 (默认10%)
        uint256 referralRate;     // 推荐人分成比例 (已废弃，保留为0)
    }

    // ==================== 事件定义 ====================

    /**
     * @dev 讲师提现事件
     */
    event InstructorWithdrawal(
        address indexed instructor,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @dev 学习进度更新事件
     */
    event ProgressUpdated(
        address indexed student,
        uint256 indexed courseId,
        uint256 completedLessons,
        uint256 progressPercent
    );

    /**
     * @dev 退款申请事件
     */
    event RefundRequested(
        uint256 indexed requestId,
        address indexed student,
        uint256 indexed courseId,
        uint256 refundAmount
    );

    /**
     * @dev 退款处理事件
     */
    event RefundProcessed(
        uint256 indexed requestId,
        address indexed student,
        uint256 indexed courseId,
        bool approved,
        uint256 refundAmount
    );

    /**
     * @dev 费率配置更新事件
     */
    event FeeConfigUpdated(
        uint256 instructorRate,
        uint256 platformRate
    );

    // ==================== 功能接口 ====================

    /**
     * @dev 讲师提现
     */
    function withdrawEarnings() external;

    /**
     * @dev 更新学习进度
     */
    function updateProgress(
        uint256 courseId,
        uint256 completedLessons
    ) external;

    /**
     * @dev 申请退款
     */
    function requestRefund(uint256 courseId) external;

    /**
     * @dev 查询讲师收益
     */
    function getInstructorEarnings(address instructor)
    external
    view
    returns (InstructorEarnings memory);

    /**
     * @dev 查询学习进度
     */
    function getProgress(address student, uint256 courseId)
    external
    view
    returns (LearningProgress memory);

    /**
     * @dev 获取费率配置
     */
    function getFeeConfig() external view returns (FeeConfig memory);
}