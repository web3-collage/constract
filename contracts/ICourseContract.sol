// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICourseContract
 * @dev 课程合约接口定义
 */
interface ICourseContract {

    /**
     * @dev 课程信息结构体
     */
    struct Course {
        uint256 id;          // 课程ID
        string title;        // 课程标题
        address instructor;  // 讲师地址
        uint256 price;       // 课程价格（YD代币）
        bool isPublished;    // 是否已发布
    }

    // ==================== 事件定义 ====================

    /**
     * @dev 课程创建事件
     * @param courseId 课程ID
     * @param instructor 讲师地址
     * @param title 课程标题
     * @param price 课程价格
     */
    event CourseCreated(
        uint256 indexed courseId,
        address indexed instructor,
        string title,
        uint256 price
    );

    /**
     * @dev 课程购买事件
     * @param courseId 课程ID
     * @param student 学生地址
     * @param instructor 讲师地址
     * @param price 支付价格
     */
    event CoursePurchased(
        uint256 indexed courseId,
        address indexed student,
        address indexed instructor,
        uint256 price
    );

    // ==================== 核心业务功能 ====================

    /**
     * @dev 创建课程
     * @param title 课程标题
     * @param instructor 教师
     * @param price 课程价格
     * @return courseId 课程ID
     */
    function createCourse(string memory title, address instructor, uint256 price) external returns (uint256 courseId);

    /**
     * @dev 购买课程
     * @param courseId 课程ID
     */
    function purchaseCourse(uint256 courseId) external;

    /**
     * @dev 检查用户是否有课程访问权限
     * @param student 学生地址
     * @param courseId 课程ID
     * @return 是否有访问权限
     */
    function hasAccess(address student, uint256 courseId) external view returns (bool);

    // ==================== 查询功能 ====================

    /**
     * @dev 获取课程信息
     * @param courseId 课程ID
     * @return 课程信息结构体
     */
    function getCourse(uint256 courseId) external view returns (Course memory);

    /**
     * @dev 获取学生购买的所有课程
     * @param student 学生地址
     * @return 课程ID数组
     */
    function getStudentCourses(address student) external view returns (uint256[] memory);

    /**
     * @dev 获取课程的所有学生
     * @param courseId 课程ID
     * @return 学生地址数组
     */
    function getCourseStudents(uint256 courseId) external view returns (address[] memory);

    /**
     * @dev 获取讲师的所有课程
     * @param instructor 讲师地址
     * @return 课程ID数组
     */
    function getInstructorCourses(address instructor) external view returns (uint256[] memory);

    // ==================== 统计功能 ====================

    /**
     * @dev 获取课程总数
     * @return 课程总数
     */
    function getTotalCourses() external view returns (uint256);

    /**
     * @dev 获取课程学生数量
     * @param courseId 课程ID
     * @return 学生数量
     */
    function getCourseStudentCount(uint256 courseId) external view returns (uint256);

    /**
     * @dev 批量检查访问权限
     * @param student 学生地址
     * @param courseIds 课程ID数组
     * @return 权限状态数组
     */
    function batchCheckAccess(address student, uint256[] memory courseIds)
    external view returns (bool[] memory);
}