// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICourseContract.sol";
import "./interfaces/IEconomicModel.sol";
import "./libraries/PaymentDistributor.sol";
import "./libraries/ProgressTracker.sol";
import "./libraries/CourseManagement.sol";
import "./libraries/PurchaseLogic.sol";
import "./libraries/RefundLogic.sol";
import "./libraries/WithdrawalLogic.sol";
import "./libraries/ReferralLogic.sol";
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
WithdrawalModule,
ReentrancyGuard
{
    using PurchaseModule for PurchaseModule.PurchaseData;
    using QueryModule for *;

    // ==================== 自定义错误 ====================
    error CourseNotExist();
    error AlreadyPurchased();
    error CannotPurchaseOwn();
    error NotPurchased();
    error NotPublished();
    error InsufficientBalance();
    error OnlyPlatform();
    error InvalidFeeSum();
    error NotInstructor();
    error InvalidAddress();

    // ==================== 状态变量 ====================

    address public platformAddress;
    uint256 public totalCourses;
    uint256 public refundWindow = 7 days; // 退款时间窗口：7天

    IEconomicModel.FeeConfig public feeConfig;

    mapping(uint256 => Course) public courses;
    mapping(address => mapping(uint256 => bool)) public hasPurchased;
    mapping(address => uint256[]) public studentCourses;
    mapping(uint256 => address[]) public courseStudents;
    mapping(uint256 => uint256) public courseStudentCount;
    mapping(address => mapping(uint256 => uint256)) public coursePrices;
    mapping(address => mapping(uint256 => uint256)) public purchaseTimestamps; // 购买时间戳
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

    event CoursePriceUpdated(
        uint256 indexed courseId,
        uint256 oldPrice,
        uint256 newPrice
    );

    event RefundWindowUpdated(uint256 oldWindow, uint256 newWindow);

    // ==================== 修饰符 ====================

    modifier courseExists(uint256 courseId) {
        if (courseId == 0 || courseId > totalCourses) revert CourseNotExist();
        _;
    }

    modifier notPurchased(address student, uint256 courseId) {
        if (hasPurchased[student][courseId]) revert AlreadyPurchased();
        _;
    }

    modifier notOwnCourse(address student, uint256 courseId) {
        if (courses[courseId].instructor == student) revert CannotPurchaseOwn();
        _;
    }

    modifier hasPurchasedCourse(address student, uint256 courseId) {
        if (!hasPurchased[student][courseId]) revert NotPurchased();
        _;
    }

    modifier onlyInstructor(uint256 courseId) {
        if (courses[courseId].instructor != msg.sender) revert NotInstructor();
        _;
    }

    // ==================== 构造函数 ====================

    constructor(address _ydToken, address _platformAddress)
    WithdrawalModule(_ydToken)
    {
        if (_ydToken == address(0) || _platformAddress == address(0)) revert InvalidAddress();

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
        CourseManagement.validateCourseParams(title, price, totalLessons);

        courseId = ++totalCourses;

        CourseManagement.createCourse(courses, courseId, title, instructor, price, totalLessons);

        emit CourseCreated(courseId, instructor, title, price, totalLessons);
        return courseId;
    }

    function purchaseCourse(uint256 courseId)
    external
    override
    nonReentrant
    courseExists(courseId)
    notPurchased(msg.sender, courseId)
    notOwnCourse(msg.sender, courseId)
    {
        _executePurchase(courseId, msg.sender);
    }

    function _executePurchase(uint256 courseId, address student) private {
        // ========== CHECKS（检查）==========
        Course storage course = courses[courseId];
        if (!course.isPublished) revert NotPublished();
        if (ydToken.balanceOf(student) < course.price) revert InsufficientBalance();

        // ========== EFFECTS（状态更新）==========
        PurchaseLogic.recordPurchase(
            hasPurchased,
            studentCourses,
            courseStudents,
            courseStudentCount,
            coursePrices,
            purchaseTimestamps,
            student,
            courseId,
            course.price
        );

        ProgressTracker.initializeProgress(progressData, student, courseId, course.totalLessons);

        // 计算并记录收益
        _processEarnings(courseId, student, course.instructor, course.price);

        // ========== INTERACTIONS（外部交互）==========
        _handlePayments(student, course.price);

        emit CoursePurchased(courseId, student, course.instructor, course.price);
    }

    function _processEarnings(
        uint256 courseId,
        address student,
        address instructor,
        uint256 price
    ) private {
        (
            uint256 instructorAmount,
            ,
            uint256 referralAmount
        ) = PurchaseLogic.calculateDistribution(price, referrers[student], feeConfig);

        WithdrawalLogic.recordEarnings(instructorEarnings, instructor, instructorAmount);

        if (referrers[student] != address(0) && referralAmount > 0) {
            ReferralLogic.recordReferralReward(referralEarnings, referrers[student], referralAmount);
            emit ReferralRewardPaid(referrers[student], student, courseId, referralAmount);
        }
    }

    function _handlePayments(address student, uint256 price) private {
        (
            ,
            uint256 platformAmount,
            uint256 referralAmount
        ) = PurchaseLogic.calculateDistribution(price, referrers[student], feeConfig);

        PurchaseLogic.handlePaymentTransfers(
            ydToken,
            student,
            platformAddress,
            referrers[student],
            price,
            platformAmount,
            referralAmount
        );
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

    function updateCoursePrice(uint256 courseId, uint256 newPrice)
    external
    courseExists(courseId)
    onlyInstructor(courseId)
    {
        uint256 oldPrice = CourseManagement.updatePrice(courses, courseId, newPrice);
        emit CoursePriceUpdated(courseId, oldPrice, newPrice);
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
    nonReentrant
    courseExists(courseId)
    hasPurchasedCourse(msg.sender, courseId)
    returns (uint256 requestId)
    {
        // ========== CHECKS（检查）==========
        address student = msg.sender;

        // 验证退款资格
        RefundLogic.validateRefundEligibility(
            purchaseTimestamps,
            progressData,
            student,
            courseId,
            refundWindow
        );

        uint256 originalAmount = coursePrices[student][courseId];

        // ========== EFFECTS（状态更新）==========
        requestId = createRefundRequest(student, courseId, originalAmount, progressData);

        (
            bool approved,
            uint256 refundAmount,
            address refundStudent,

        ) = processRefund(requestId);

        if (approved) {
            // 处理推荐人收益回退
            RefundLogic.handleReferralRollback(
                referralEarnings,
                referrers[refundStudent],
                originalAmount,
                feeConfig.referralRate
            );

            // ========== INTERACTIONS（外部交互）==========
            PaymentDistributor.safeTransfer(ydToken, refundStudent, refundAmount);
        }

        return requestId;
    }

    // ==================== 推荐系统 ====================

    function setReferrer(address referrer)
    external
    override(ICourseContract, ReferralModule)
    {
        ReferralLogic.setReferrer(referrers, referredUsers, referralCount, msg.sender, referrer);
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
    nonReentrant
    returns (uint256 amount)
    {
        amount = WithdrawalLogic.executeWithdrawal(
            ydToken,
            instructorEarnings,
            withdrawalHistory,
            lastWithdrawalTime,
            msg.sender,
            minWithdrawalAmount,
            withdrawalCooldown
        );

        emit InstructorWithdrawal(msg.sender, amount, block.timestamp);
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
        if (msg.sender != platformAddress) revert OnlyPlatform();
        if (newConfig.instructorRate + newConfig.platformRate + newConfig.referralRate != 100) revert InvalidFeeSum();

        feeConfig = newConfig;

        emit FeeConfigUpdated(
            newConfig.instructorRate,
            newConfig.platformRate,
            newConfig.referralRate
        );
    }

    function updateRefundWindow(uint256 newWindow) external {
        if (msg.sender != platformAddress) revert OnlyPlatform();

        uint256 oldWindow = refundWindow;
        refundWindow = newWindow;

        emit RefundWindowUpdated(oldWindow, newWindow);
    }

    function getPurchaseTimestamp(address student, uint256 courseId)
    external
    view
    returns (uint256)
    {
        return purchaseTimestamps[student][courseId];
    }

    function canRefund(address student, uint256 courseId)
    external
    view
    courseExists(courseId)
    returns (bool canRefundNow, string memory reason)
    {
        return RefundLogic.checkRefundability(
            hasPurchased,
            hasRefunded,
            purchaseTimestamps,
            progressData,
            student,
            courseId,
            refundWindow
        );
    }
}
