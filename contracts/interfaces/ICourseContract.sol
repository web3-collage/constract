// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IEconomicModel.sol";

/**
 * @title ICourseContract
 * @dev 课程合约接口定义（包含经济模型功能）
 */
interface ICourseContract {

    /**
     * @dev 课程信息结构体
     * @notice 优化存储布局：将 bool 和 address 打包到同一个 slot
     * Slot 0: id (uint256)
     * Slot 1: instructor (address, 20 bytes) + isPublished (bool, 1 byte) + totalLessons (uint96, 12 bytes) = 33 bytes (需要2个slot)
     * 实际布局:
     * Slot 1: instructor (20 bytes) + isPublished (1 byte)
     * Slot 2: totalLessons (uint96, 打包优化)
     * Slot 3: price (uint256)
     * Slot N: title (string, 动态)
     */
    struct Course {
        uint256 id;          // 课程ID
        address instructor;  // 讲师地址 (20 bytes)
        bool isPublished;    // 是否已发布 (1 byte) - 与 instructor 打包
        uint96 totalLessons; // 总课时数 (12 bytes, 足够存储) - 与 instructor 打包
        uint256 price;       // 课程价格（YD代币）
        string title;        // 课程标题 (最后，因为是动态类型)
    }

    // ==================== 事件定义 ====================

    event CourseCreated(
        uint256 indexed courseId,
        address indexed instructor,
        string title,
        uint256 price,
        uint256 totalLessons
    );

    event CoursePurchased(
        uint256 indexed courseId,
        address indexed student,
        address indexed instructor,
        uint256 price
    );

    // ==================== 核心业务功能 ====================

    function createCourse(
        string memory title,
        address instructor,
        uint256 price,
        uint256 totalLessons
    ) external returns (uint256 courseId);

    function purchaseCourse(uint256 courseId) external;

    function hasAccess(address student, uint256 courseId) external view returns (bool);

    // ==================== 查询功能 ====================

    function getCourse(uint256 courseId) external view returns (Course memory);

    function getStudentCourses(address student) external view returns (uint256[] memory);

    function getCourseStudents(uint256 courseId) external view returns (address[] memory);

    function getInstructorCourses(address instructor) external view returns (uint256[] memory);

    function getTotalCourses() external view returns (uint256);

    function getCourseStudentCount(uint256 courseId) external view returns (uint256);

    function batchCheckAccess(address student, uint256[] memory courseIds)
    external view returns (bool[] memory);

    // ==================== 经济模型功能 ====================

    // 讲师提现
    function withdrawEarnings() external returns (uint256);

    function getInstructorEarnings(address instructor)
    external view returns (IEconomicModel.InstructorEarnings memory);

    // 学习进度
    function updateProgress(uint256 courseId, uint256 completedLessons) external;

    function getProgress(address student, uint256 courseId)
    external view returns (IEconomicModel.LearningProgress memory);

    // 退款系统
    function requestRefund(uint256 courseId) external returns (uint256 requestId);

    function getRefundRequest(uint256 requestId)
    external view returns (IEconomicModel.RefundRequest memory);

    // 费率配置
    function getFeeConfig() external view returns (IEconomicModel.FeeConfig memory);
}