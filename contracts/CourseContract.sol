// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICourseContract.sol";
import "./interfaces/IEconomicModel.sol";
import "./libraries/PaymentDistributor.sol";
import "./libraries/ProgressTracker.sol";
import "./libraries/CourseManagement.sol";
import "./libraries/PurchaseLogic.sol";
import "./libraries/RefundLogic.sol";
import "./libraries/WithdrawalLogic.sol";
import "./modules/RefundModule.sol";
import "./modules/WithdrawalModule.sol";
import "./modules/PurchaseModule.sol";
import "./modules/QueryModule.sol";

/**
 * @title CourseContract
 * @dev 完整版课程合约（包含经济模型）
 * @notice 提供课程管理、支付分账、进度追踪、退款、提现等功能
 */
contract CourseContract is
ICourseContract,
RefundModule,
WithdrawalModule,
ReentrancyGuard,
Pausable
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
    error NotCertifiedInstructor();
    error AlreadyCertified();
    error NotAuthorized();

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

    // Gas 优化：添加讲师课程列表，避免遍历所有课程
    mapping(address => uint256[]) public instructorCourses;

    // 讲师认证系统
    mapping(address => bool) public certifiedInstructors;
    uint256 public certifiedInstructorCount;

    // ==================== 事件定义 ====================

    event InstructorCertified(address indexed instructor, uint256 timestamp);
    event InstructorRevoked(address indexed instructor, uint256 timestamp);

    event ProgressUpdated(
        address indexed student,
        uint256 indexed courseId,
        uint256 completedLessons,
        uint256 progressPercent
    );

    event FeeConfigUpdated(
        uint256 instructorRate,
        uint256 platformRate
    );

    event CoursePriceUpdated(
        uint256 indexed courseId,
        uint256 oldPrice,
        uint256 newPrice
    );

    event RefundWindowUpdated(uint256 oldWindow, uint256 newWindow);

    event CourseUpdated(
        uint256 indexed courseId,
        string title,
        uint256 totalLessons
    );

    event CoursePublished(uint256 indexed courseId, uint256 timestamp);
    event CourseUnpublished(uint256 indexed courseId, uint256 timestamp);

    event CourseDeleted(uint256 indexed courseId, address indexed instructor, uint256 timestamp);

    event PlatformAddressUpdated(address indexed oldAddress, address indexed newAddress);

    event EmergencyPaused(address indexed admin, uint256 timestamp);
    event EmergencyUnpaused(address indexed admin, uint256 timestamp);

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

    modifier onlyCertifiedInstructor() {
        if (!certifiedInstructors[msg.sender]) revert NotCertifiedInstructor();
        _;
    }

    modifier onlyPlatformAdmin() {
        if (msg.sender != platformAddress) revert OnlyPlatform();
        _;
    }

    // ==================== 构造函数 ====================

    constructor(address _ydToken, address _platformAddress)
    WithdrawalModule(_ydToken)
    {
        if (_ydToken == address(0) || _platformAddress == address(0)) revert InvalidAddress();

        platformAddress = _platformAddress;

        feeConfig = IEconomicModel.FeeConfig({
            instructorRate: 90,
            platformRate: 10,
            referralRate: 0
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
    onlyCertifiedInstructor
    returns (uint256 courseId)
    {
        CourseManagement.validateCourseParams(title, price, totalLessons);

        // 只有认证讲师可以为自己创建课程
        if (instructor != msg.sender) revert NotAuthorized();

        courseId = ++totalCourses;

        CourseManagement.createCourse(courses, courseId, title, instructor, price, totalLessons);

        // Gas 优化：记录讲师课程列表
        instructorCourses[instructor].push(courseId);

        emit CourseCreated(courseId, instructor, title, price, totalLessons);
        return courseId;
    }

    function purchaseCourse(uint256 courseId)
    external
    override
    nonReentrant
    whenNotPaused
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
        uint256 /* courseId */,
        address /* student */,
        address instructor,
        uint256 price
    ) private {
        (
            uint256 instructorAmount,
            ,

        ) = PurchaseLogic.calculateDistribution(price, address(0), feeConfig);

        WithdrawalLogic.recordEarnings(instructorEarnings, instructor, instructorAmount);
    }

    function _handlePayments(address student, uint256 price) private {
        (
            ,
            uint256 platformAmount,

        ) = PurchaseLogic.calculateDistribution(price, address(0), feeConfig);

        PurchaseLogic.handlePaymentTransfers(
            ydToken,
            student,
            platformAddress,
            address(0),
            price,
            platformAmount,
            0
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
        // Gas 优化：直接返回存储的列表，避免遍历所有课程
        return instructorCourses[instructor];
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
    whenNotPaused
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
        address instructor = courses[courseId].instructor;

        // ========== EFFECTS（状态更新）==========
        requestId = createRefundRequest(student, courseId, originalAmount, progressData);

        (
            bool approved,
            uint256 refundAmount,
            address refundStudent,

        ) = processRefund(requestId);

        if (approved) {
            // 修复：扣除讲师的pending余额（退款70%，讲师需要返还的是原价的90% * 70% = 63%）
            // 计算讲师原本应得的收益
            (uint256 instructorAmount, , ) = PurchaseLogic.calculateDistribution(
                originalAmount,
                address(0),
                feeConfig
            );

            // 计算退款对应的讲师份额（70%的退款中，讲师需要返还的部分）
            uint256 instructorRefundAmount = (instructorAmount * 70) / 100;

            // 从讲师的pending余额中扣除
            WithdrawalLogic.deductEarnings(instructorEarnings, instructor, instructorRefundAmount);

            // ========== INTERACTIONS（外部交互）==========
            PaymentDistributor.safeTransfer(ydToken, refundStudent, refundAmount);
        }

        return requestId;
    }


    // ==================== 讲师提现 ====================

    function withdrawEarnings()
    external
    override(ICourseContract, WithdrawalModule)
    nonReentrant
    whenNotPaused
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
        if (newConfig.instructorRate + newConfig.platformRate != 100) revert InvalidFeeSum();

        feeConfig = newConfig;

        emit FeeConfigUpdated(
            newConfig.instructorRate,
            newConfig.platformRate
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

    // ==================== 讲师认证管理 ====================

    /**
     * @dev 认证讲师（仅平台管理员）
     * @param instructor 讲师地址
     */
    function certifyInstructor(address instructor) external onlyPlatformAdmin {
        if (instructor == address(0)) revert InvalidAddress();
        if (certifiedInstructors[instructor]) revert AlreadyCertified();

        certifiedInstructors[instructor] = true;
        certifiedInstructorCount++;

        emit InstructorCertified(instructor, block.timestamp);
    }

    /**
     * @dev 撤销讲师认证（仅平台管理员）
     * @param instructor 讲师地址
     */
    function revokeInstructor(address instructor) external onlyPlatformAdmin {
        if (!certifiedInstructors[instructor]) revert NotCertifiedInstructor();

        certifiedInstructors[instructor] = false;
        certifiedInstructorCount--;

        emit InstructorRevoked(instructor, block.timestamp);
    }

    /**
     * @dev 批量认证讲师（仅平台管理员）
     * @param instructors 讲师地址列表
     * @notice Gas优化：限制批量操作的最大数量，防止gas超限
     */
    function batchCertifyInstructors(address[] calldata instructors) external onlyPlatformAdmin {
        // Gas优化：限制单次批量操作最多100个地址
        require(instructors.length <= 100, "Batch size exceeds limit");

        for (uint256 i = 0; i < instructors.length; i++) {
            address instructor = instructors[i];
            if (instructor != address(0) && !certifiedInstructors[instructor]) {
                certifiedInstructors[instructor] = true;
                certifiedInstructorCount++;
                emit InstructorCertified(instructor, block.timestamp);
            }
        }
    }

    /**
     * @dev 检查是否为认证讲师
     * @param instructor 讲师地址
     * @return 是否认证
     */
    function isCertifiedInstructor(address instructor) external view returns (bool) {
        return certifiedInstructors[instructor];
    }

    // ==================== 课程管理扩展 ====================

    /**
     * @dev 更新课程信息（仅讲师）
     * @param courseId 课程ID
     * @param title 新标题
     * @param totalLessons 新课时数
     */
    function updateCourse(
        uint256 courseId,
        string memory title,
        uint96 totalLessons
    ) external courseExists(courseId) onlyInstructor(courseId) {
        if (bytes(title).length == 0) revert CourseManagement.EmptyTitle();
        if (bytes(title).length > 100) revert CourseManagement.TitleTooLong();
        if (totalLessons == 0) revert CourseManagement.InvalidLessons();

        Course storage course = courses[courseId];
        course.title = title;
        course.totalLessons = totalLessons;

        emit CourseUpdated(courseId, title, totalLessons);
    }

    /**
     * @dev 发布课程（仅讲师）
     * @param courseId 课程ID
     */
    function publishCourse(uint256 courseId) external courseExists(courseId) onlyInstructor(courseId) {
        Course storage course = courses[courseId];
        if (course.isPublished) revert("Already published");

        course.isPublished = true;
        emit CoursePublished(courseId, block.timestamp);
    }

    /**
     * @dev 取消发布课程（仅讲师）
     * @param courseId 课程ID
     */
    function unpublishCourse(uint256 courseId) external courseExists(courseId) onlyInstructor(courseId) {
        Course storage course = courses[courseId];
        if (!course.isPublished) revert("Not published");

        course.isPublished = false;
        emit CourseUnpublished(courseId, block.timestamp);
    }

    /**
     * @dev 删除课程（仅讲师，且无学生购买）
     * @param courseId 课程ID
     */
    function deleteCourse(uint256 courseId) external courseExists(courseId) onlyInstructor(courseId) {
        if (courseStudentCount[courseId] > 0) revert("Cannot delete: has students");

        Course storage course = courses[courseId];
        address instructor = course.instructor;

        // 标记为删除（软删除）
        course.isPublished = false;
        course.price = 0;

        emit CourseDeleted(courseId, instructor, block.timestamp);
    }

    /**
     * @dev 更新平台地址（仅平台管理员）
     * @param newPlatformAddress 新平台地址
     */
    function updatePlatformAddress(address newPlatformAddress) external onlyPlatformAdmin {
        if (newPlatformAddress == address(0)) revert InvalidAddress();

        address oldAddress = platformAddress;
        platformAddress = newPlatformAddress;

        emit PlatformAddressUpdated(oldAddress, newPlatformAddress);
    }

    // ==================== 紧急控制 ====================

    /**
     * @dev 紧急暂停合约（仅平台管理员）
     * @notice 暂停所有关键操作：购买课程、申请退款、提现
     */
    function pause() external onlyPlatformAdmin {
        _pause();
        emit EmergencyPaused(msg.sender, block.timestamp);
    }

    /**
     * @dev 恢复合约运行（仅平台管理员）
     */
    function unpause() external onlyPlatformAdmin {
        _unpause();
        emit EmergencyUnpaused(msg.sender, block.timestamp);
    }

    /**
     * @dev 检查合约是否已暂停
     * @return 暂停状态
     */
    function isPaused() external view returns (bool) {
        return paused();
    }
}
