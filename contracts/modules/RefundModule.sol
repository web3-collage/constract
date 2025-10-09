// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IEconomicModel.sol";
import "../libraries/ProgressTracker.sol";
import "../libraries/PaymentDistributor.sol";
import "../libraries/WithdrawalLogic.sol";

/**
 * @title RefundModule
 * @dev 退款管理模块
 * @notice 处理学生的退款申请，验证资格并执行退款
 */
contract RefundModule {

    // ==================== 自定义错误 ====================
    error AlreadyRefunded();
    error RefundNotFound();
    error AlreadyProcessed();
    error ProgressTooHigh();

    // ==================== 状态变量 ====================

    uint256 public totalRefundRequests;
    mapping(uint256 => IEconomicModel.RefundRequest) public refundRequests;
    mapping(address => mapping(uint256 => uint256)) public studentRefundIds;
    mapping(address => mapping(uint256 => bool)) public hasRefunded;

    // ==================== 事件定义 ====================

    event RefundRequested(
        uint256 indexed requestId,
        address indexed student,
        uint256 indexed courseId,
        uint256 refundAmount
    );

    event RefundProcessed(
        uint256 indexed requestId,
        address indexed student,
        uint256 indexed courseId,
        bool approved,
        uint256 refundAmount
    );

    // ==================== 修饰符 ====================

    modifier notRefunded(address student, uint256 courseId) {
        if (hasRefunded[student][courseId]) revert AlreadyRefunded();
        _;
    }

    modifier refundExists(uint256 requestId) {
        if (requestId == 0 || requestId > totalRefundRequests) revert RefundNotFound();
        _;
    }

    modifier notProcessed(uint256 requestId) {
        if (refundRequests[requestId].processed) revert AlreadyProcessed();
        _;
    }

    // ==================== 核心功能 ====================

    /**
     * @dev 创建退款申请
     * @param student 学生地址
     * @param courseId 课程ID
     * @param originalAmount 原始购买金额
     * @param progressData 进度数据（用于验证资格）
     * @return requestId 退款申请ID
     */
    function createRefundRequest(
        address student,
        uint256 courseId,
        uint256 originalAmount,
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) storage progressData
    )
    internal
    notRefunded(student, courseId)
    returns (uint256 requestId)
    {
        // 验证退款资格（学习进度<30%）
        if (!ProgressTracker.isRefundEligible(progressData, student, courseId)) revert ProgressTooHigh();

        // 计算退款金额（70%）
        uint256 refundAmount = PaymentDistributor.calculateRefundAmount(originalAmount);

        // 创建退款申请
        requestId = ++totalRefundRequests;

        refundRequests[requestId] = IEconomicModel.RefundRequest({
            courseId: courseId,
            student: student,
            refundAmount: refundAmount,
            requestTime: block.timestamp,
            processed: false,
            approved: false
        });

        studentRefundIds[student][courseId] = requestId;

        emit RefundRequested(requestId, student, courseId, refundAmount);
        return requestId;
    }

    /**
     * @dev 处理退款申请（自动批准符合条件的申请）
     * @param requestId 退款申请ID
     * @return approved 是否批准
     * @return refundAmount 退款金额
     * @return student 学生地址
     * @return courseId 课程ID
     */
    function processRefund(uint256 requestId)
    internal
    refundExists(requestId)
    notProcessed(requestId)
    returns (
        bool approved,
        uint256 refundAmount,
        address student,
        uint256 courseId
    )
    {
        IEconomicModel.RefundRequest storage request = refundRequests[requestId];

        // 标记为已处理和已批准
        request.processed = true;
        request.approved = true;

        // 标记该课程已退款
        hasRefunded[request.student][request.courseId] = true;

        emit RefundProcessed(
            requestId,
            request.student,
            request.courseId,
            true,
            request.refundAmount
        );

        return (
            true,
            request.refundAmount,
            request.student,
            request.courseId
        );
    }

    // ==================== 查询功能 ====================

    /**
     * @dev 获取退款申请详情
     * @param requestId 退款申请ID
     * @return 退款申请信息
     */
    function getRefundRequest(uint256 requestId)
    external
    view
    virtual
    refundExists(requestId)
    returns (IEconomicModel.RefundRequest memory)
    {
        return refundRequests[requestId];
    }

    /**
     * @dev 获取学生课程的退款申请ID
     * @param student 学生地址
     * @param courseId 课程ID
     * @return 退款申请ID（0表示未申请）
     */
    function getStudentRefundId(address student, uint256 courseId)
    external
    view
    returns (uint256)
    {
        return studentRefundIds[student][courseId];
    }

    /**
     * @dev 检查是否已退款
     * @param student 学生地址
     * @param courseId 课程ID
     * @return 是否已退款
     */
    function isRefunded(address student, uint256 courseId)
    external
    view
    returns (bool)
    {
        return hasRefunded[student][courseId];
    }

    /**
     * @dev 获取退款申请总数
     * @return 总数
     */
    function getTotalRefundRequests() external view returns (uint256) {
        return totalRefundRequests;
    }
}