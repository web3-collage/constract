// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IERC20.sol";
import "./ICourseContract.sol";

/**
 * @title CourseContract
 * @dev 极简版课程合约实现
 * @notice 提供课程创建、购买、查询等核心功能
 */
contract CourseContract is ICourseContract {

    // ==================== 状态变量 ====================

    IERC20 public ydToken;              // YD代币合约
    address public platformAddress;      // 平台收益地址
    uint256 public totalCourses;        // 课程总数计数器

    // 数据存储映射
    mapping(uint256 => Course) public courses;                           // 课程信息存储
    mapping(address => mapping(uint256 => bool)) public hasPurchased;    // 用户购买状态
    mapping(address => uint256[]) public studentCourses;                 // 学生课程列表
    mapping(uint256 => address[]) public courseStudents;                // 课程学生列表
    mapping(uint256 => uint256) public courseStudentCount;              // 课程学生计数

    // ==================== 修饰符 ====================

    /**
     * @dev 验证课程是否存在
     */
    modifier courseExists(uint256 courseId) {
        require(courseId > 0 && courseId <= totalCourses, "Course does not exist");
        _;
    }

    /**
     * @dev 验证用户未购买该课程
     */
    modifier notPurchased(address student, uint256 courseId) {
        require(!hasPurchased[student][courseId], "Course already purchased");
        _;
    }

    /**
     * @dev 验证用户不是课程讲师（防止自己购买自己的课程）
     */
    modifier notOwnCourse(address student, uint256 courseId) {
        require(courses[courseId].instructor != student, "Cannot purchase own course");
        _;
    }

    // ==================== 构造函数 ====================

    /**
     * @dev 构造函数
     * @param _ydToken YD代币合约地址
     * @param _platformAddress 平台收益地址
     */
    constructor(address _ydToken, address _platformAddress) {
        require(_ydToken != address(0), "YD token address cannot be zero");
        require(_platformAddress != address(0), "Platform address cannot be zero");

        ydToken = IERC20(_ydToken);
        platformAddress = _platformAddress;
    }

    // ==================== 核心业务功能 ====================

    /**
     * @dev 创建课程
     * @param title 课程标题
     * @param price 课程价格（YD代币）
     * @return courseId 新创建的课程ID
     */
    function createCourse(string memory title, address instructor, uint256 price)
    external
    override
    returns (uint256 courseId)
    {
        require(bytes(title).length > 0, "Course title cannot be empty");
        require(bytes(title).length <= 100, "Course title too long");
        require(price > 0, "Course price must be greater than zero");
        require(price < 500 * 1e18, "Course price must be less than 500");

        // 生成新的课程ID
        courseId = ++totalCourses;

        // 创建课程
        courses[courseId] = Course({
            id: courseId,
            title: title,
            instructor: instructor,
            price: price,
            isPublished: true  // 简化版直接发布，无需审核
        });

        emit CourseCreated(courseId, instructor, title, price);
        return courseId;
    }

    /**
     * @dev 购买课程
     * @param courseId 课程ID
     */
    function purchaseCourse(uint256 courseId)
    external
    override
    courseExists(courseId)
    notPurchased(msg.sender, courseId)
    notOwnCourse(msg.sender, courseId)
    {
        Course storage course = courses[courseId];
        require(course.isPublished, "Course is not published");

        address student = msg.sender;
        address instructor = course.instructor;
        uint256 price = course.price;

        // 验证用户余额
        require(ydToken.balanceOf(student) >= price, "Insufficient YD balance");

        // 从学生账户转移YD到合约
        require(
            ydToken.transferFrom(student, address(this), price),
            "YD transfer failed"
        );

        // 执行分账：90%给讲师，10%给平台
        _distributePayment(instructor, price);

        // 记录购买关系
        _recordPurchase(student, courseId);

        emit CoursePurchased(courseId, student, instructor, price);
    }

    /**
     * @dev 检查用户访问权限
     * @param student 学生地址
     * @param courseId 课程ID
     * @return 是否有访问权限
     */
    function hasAccess(address student, uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (bool)
    {
        return hasPurchased[student][courseId];
    }

    // ==================== 查询功能 ====================

    /**
     * @dev 获取课程信息
     * @param courseId 课程ID
     * @return 课程信息结构体
     */
    function getCourse(uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (Course memory)
    {
        return courses[courseId];
    }

    /**
     * @dev 获取学生购买的所有课程
     * @param student 学生地址
     * @return 课程ID数组
     */
    function getStudentCourses(address student)
    external
    view
    override
    returns (uint256[] memory)
    {
        return studentCourses[student];
    }

    /**
     * @dev 获取课程的所有学生
     * @param courseId 课程ID
     * @return 学生地址数组
     */
    function getCourseStudents(uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (address[] memory)
    {
        return courseStudents[courseId];
    }

    /**
     * @dev 获取讲师的所有课程
     * @param instructor 讲师地址
     * @return 课程ID数组
     */
    function getInstructorCourses(address instructor)
    external
    view
    override
    returns (uint256[] memory)
    {
        // 创建动态数组存储结果
        uint256[] memory tempResults = new uint256[](totalCourses);
        uint256 count = 0;

        // 遍历所有课程，找到属于该讲师的课程
        for (uint256 i = 1; i <= totalCourses; i++) {
            if (courses[i].instructor == instructor) {
                tempResults[count] = i;
                count++;
            }
        }

        // 创建精确大小的结果数组
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tempResults[i];
        }

        return result;
    }

    // ==================== 统计功能 ====================

    /**
     * @dev 获取课程总数
     * @return 课程总数
     */
    function getTotalCourses() external view override returns (uint256) {
        return totalCourses;
    }

    /**
     * @dev 获取课程学生数量
     * @param courseId 课程ID
     * @return 学生数量
     */
    function getCourseStudentCount(uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (uint256)
    {
        return courseStudentCount[courseId];
    }

    /**
     * @dev 批量检查访问权限
     * @param student 学生地址
     * @param courseIds 课程ID数组
     * @return 权限状态数组
     */
    function batchCheckAccess(address student, uint256[] memory courseIds)
    external
    view
    override
    returns (bool[] memory)
    {
        bool[] memory results = new bool[](courseIds.length);

        for (uint256 i = 0; i < courseIds.length; i++) {
            uint256 courseId = courseIds[i];
            // 检查课程是否存在且用户是否已购买
            if (courseId > 0 && courseId <= totalCourses) {
                results[i] = hasPurchased[student][courseId];
            } else {
                results[i] = false;
            }
        }

        return results;
    }

    // ==================== 内部辅助函数 ====================

    /**
     * @dev 执行分账逻辑
     * @param instructor 讲师地址
     * @param amount 总金额
     */
    function _distributePayment(address instructor, uint256 amount) internal {
        // 计算分成：90%给讲师，10%给平台
        uint256 instructorAmount = (amount * 90) / 100;
        uint256 platformAmount = amount - instructorAmount;

        // 转账给讲师
        require(
            ydToken.transfer(instructor, instructorAmount),
            "Transfer to instructor failed"
        );

        // 转账给平台
        require(
            ydToken.transfer(platformAddress, platformAmount),
            "Transfer to platform failed"
        );
    }

    /**
     * @dev 记录购买关系
     * @param student 学生地址
     * @param courseId 课程ID
     */
    function _recordPurchase(address student, uint256 courseId) internal {
        // 标记为已购买
        hasPurchased[student][courseId] = true;

        // 添加到学生课程列表
        studentCourses[student].push(courseId);

        // 添加到课程学生列表
        courseStudents[courseId].push(student);

        // 增加课程学生计数
        courseStudentCount[courseId]++;
    }
}