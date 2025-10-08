// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IERC20.sol";
import "./interfaces/ICourseContract.sol";
import "./interfaces/IEconomicModel.sol";
import "./libraries/PaymentDistributor.sol";
import "./libraries/ProgressTracker.sol";
import "./modules/ReferralModule.sol";
import "./modules/RefundModule.sol";
import "./modules/WithdrawalModule.sol";
import "./modules/PurchaseModule.sol";
import "./modules/QueryModule.sol";

/**
 * @title CourseContract
 * @dev 完整版课程合约（包含经济模型）
 * @notice 提供课程管理、支付分账、推荐奖励、进度追踪、退款、提现等功能
 */
contract CourseContract is
ICourseContract,
ReferralModule,
RefundModule,
WithdrawalModule
{
    using PurchaseModule for PurchaseModule.PurchaseData;
    using QueryModule for *;

    // ==================== 状态变量 ====================

    address public platformAddress;
    uint256 public totalCourses;

    IEconomicModel.FeeConfig public feeConfig;

    mapping(uint256 => Course) public courses;
    mapping(address => mapping(uint256 => bool)) public hasPurchased;
    mapping(address => uint256[]) public studentCourses;
    mapping(uint256 => address[]) public courseStudents;
    mapping(uint256 => uint256) public courseStudentCount;
    mapping(address => mapping(uint256 => uint256)) public coursePrices;
    mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) public progressData;

    // ==================== 事件定义 ====================

    event ProgressUpdated(
        address indexed student,
        uint256 indexed courseId,
        uint256 completedLessons,
        uint256 progressPercent
    );

    event FeeConfigUpdated(
        uint256 instructorRate,
        uint256 platformRate,
        uint256 referralRate
    );

    // ==================== 修饰符 ====================

    modifier courseExists(uint256 courseId) {
        require(courseId > 0 && courseId <= totalCourses, "Course does not exist");
        _;
    }

    modifier notPurchased(address student, uint256 courseId) {
        require(!hasPurchased[student][courseId], "Course already purchased");
        _;
    }

    modifier notOwnCourse(address student, uint256 courseId) {
        require(courses[courseId].instructor != student, "Cannot purchase own course");
        _;
    }

    modifier hasPurchasedCourse(address student, uint256 courseId) {
        require(hasPurchased[student][courseId], "Course not purchased");
        _;
    }

    // ==================== 构造函数 ====================

    constructor(address _ydToken, address _platformAddress)
    WithdrawalModule(_ydToken)
    {
        require(_ydToken != address(0), "YD token address cannot be zero");
        require(_platformAddress != address(0), "Platform address cannot be zero");

        platformAddress = _platformAddress;

        feeConfig = IEconomicModel.FeeConfig({
            instructorRate: 85,
            platformRate: 10,
            referralRate: 5
        });
    }

    // ==================== 课程管理功能 ====================

    function createCourse(
        string memory title,
        address instructor,
        uint256 price,
        uint256 totalLessons
    )
    external
    override
    returns (uint256 courseId)
    {
        require(bytes(title).length > 0, "Course title cannot be empty");
        require(bytes(title).length <= 100, "Course title too long");
        require(price > 0, "Course price must be greater than zero");
        require(price < 500 * 1e18, "Course price must be less than 500");
        require(totalLessons > 0, "Total lessons must be greater than zero");
        require(totalLessons <= 1000, "Total lessons too many");

        courseId = ++totalCourses;

        courses[courseId] = Course({
            id: courseId,
            title: title,
            instructor: instructor,
            price: price,
            totalLessons: totalLessons,
            isPublished: true
        });

        emit CourseCreated(courseId, instructor, title, price, totalLessons);
        return courseId;
    }

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
        uint256 price = course.price;

        require(ydToken.balanceOf(student) >= price, "Insufficient YD balance");

        (
            uint256 instructorAmount,
            uint256 platformAmount,
            uint256 referralAmount
        ) = PaymentDistributor.distributePayment(
            ydToken,
            student,
            course.instructor,
            platformAddress,
            referrers[student],
            price,
            feeConfig
        );

        _recordEarnings(course.instructor, instructorAmount);
        PaymentDistributor.safeTransfer(ydToken, platformAddress, platformAmount);

        if (referrers[student] != address(0) && referralAmount > 0) {
            PaymentDistributor.safeTransfer(ydToken, referrers[student], referralAmount);
            _recordReferralReward(referrers[student], student, courseId, referralAmount);
        }

        hasPurchased[student][courseId] = true;
        studentCourses[student].push(courseId);
        courseStudents[courseId].push(student);
        courseStudentCount[courseId]++;
        coursePrices[student][courseId] = price;

        ProgressTracker.initializeProgress(progressData, student, courseId, course.totalLessons);

        emit CoursePurchased(courseId, student, course.instructor, price);
    }

    function hasAccess(address student, uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (bool)
    {
        return hasPurchased[student][courseId] && !hasRefunded[student][courseId];
    }

    // ==================== 查询功能 ====================

    function getCourse(uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (Course memory)
    {
        return courses[courseId];
    }

    function getStudentCourses(address student)
    external
    view
    override
    returns (uint256[] memory)
    {
        return studentCourses[student];
    }

    function getCourseStudents(uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (address[] memory)
    {
        return courseStudents[courseId];
    }

    function getInstructorCourses(address instructor)
    external
    view
    override
    returns (uint256[] memory)
    {
        return QueryModule.getInstructorCourses(courses, totalCourses, instructor);
    }

    function getTotalCourses() external view override returns (uint256) {
        return totalCourses;
    }

    function getCourseStudentCount(uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (uint256)
    {
        return courseStudentCount[courseId];
    }

    function batchCheckAccess(address student, uint256[] memory courseIds)
    external
    view
    override
    returns (bool[] memory)
    {
        return QueryModule.batchCheckAccess(hasPurchased, hasRefunded, totalCourses, student, courseIds);
    }

    // ==================== 学习进度功能 ====================

    function updateProgress(uint256 courseId, uint256 completedLessons)
    external
    override
    courseExists(courseId)
    hasPurchasedCourse(msg.sender, courseId)
    {
        ProgressTracker.updateProgress(progressData, msg.sender, courseId, completedLessons);

        emit ProgressUpdated(
            msg.sender,
            courseId,
            completedLessons,
            progressData[msg.sender][courseId].progressPercent
        );
    }

    function getProgress(address student, uint256 courseId)
    external
    view
    override
    courseExists(courseId)
    returns (IEconomicModel.LearningProgress memory)
    {
        return ProgressTracker.getProgress(progressData, student, courseId);
    }

    // ==================== 退款功能 ====================

    function requestRefund(uint256 courseId)
    external
    override
    courseExists(courseId)
    hasPurchasedCourse(msg.sender, courseId)
    returns (uint256 requestId)
    {
        address student = msg.sender;
        uint256 originalAmount = coursePrices[student][courseId];

        requestId = createRefundRequest(student, courseId, originalAmount, progressData);

        (
            bool approved,
            uint256 refundAmount,
            address refundStudent,

        ) = processRefund(requestId);

        if (approved) {
            PaymentDistributor.safeTransfer(ydToken, refundStudent, refundAmount);

            address referrer = referrers[refundStudent];
            if (referrer != address(0)) {
                uint256 referralAmount = (originalAmount * feeConfig.referralRate) / 100;
                if (referralEarnings[referrer] >= referralAmount) {
                    referralEarnings[referrer] -= referralAmount;
                }
            }
        }

        return requestId;
    }

    // ==================== 推荐系统 ====================

    function setReferrer(address referrer)
    external
    override(ICourseContract, ReferralModule)
    referrerNotSet(msg.sender)
    notSelfReferral(msg.sender, referrer)
    validReferrer(referrer)
    {
        referrers[msg.sender] = referrer;
        referredUsers[referrer].push(msg.sender);
        referralCount[referrer]++;

        emit ReferralSet(msg.sender, referrer);
    }

    function getReferrer(address user)
    external
    view
    override(ICourseContract, ReferralModule)
    returns (address)
    {
        return referrers[user];
    }

    function getReferralEarnings(address referrer)
    external
    view
    override(ICourseContract, ReferralModule)
    returns (uint256)
    {
        return referralEarnings[referrer];
    }

    // ==================== 讲师提现 ====================

    function withdrawEarnings()
    external
    override(ICourseContract, WithdrawalModule)
    hasPendingEarnings(msg.sender)
    cooldownPassed(msg.sender)
    returns (uint256 amount)
    {
        address instructor = msg.sender;
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        amount = earnings.pending;

        earnings.withdrawn += amount;
        earnings.pending = 0;

        withdrawalHistory[instructor].push(block.timestamp);
        lastWithdrawalTime[instructor] = block.timestamp;

        require(
            ydToken.transfer(instructor, amount),
            "YD transfer failed"
        );

        emit InstructorWithdrawal(instructor, amount, block.timestamp);
        return amount;
    }

    function getInstructorEarnings(address instructor)
    external
    view
    override(ICourseContract, WithdrawalModule)
    returns (IEconomicModel.InstructorEarnings memory)
    {
        return instructorEarnings[instructor];
    }

    // ==================== 退款查询 ====================

    function getRefundRequest(uint256 requestId)
    external
    view
    override(ICourseContract, RefundModule)
    refundExists(requestId)
    returns (IEconomicModel.RefundRequest memory)
    {
        return refundRequests[requestId];
    }

    // ==================== 费率配置 ====================

    function getFeeConfig()
    external
    view
    override
    returns (IEconomicModel.FeeConfig memory)
    {
        return feeConfig;
    }

    function updateFeeConfig(IEconomicModel.FeeConfig memory newConfig) external {
        require(msg.sender == platformAddress, "Only platform can update fee config");
        require(
            newConfig.instructorRate + newConfig.platformRate + newConfig.referralRate == 100,
            "Fee rates must sum to 100"
        );

        feeConfig = newConfig;

        emit FeeConfigUpdated(
            newConfig.instructorRate,
            newConfig.platformRate,
            newConfig.referralRate
        );
    }
}
