

// Sources flattened with hardhat v2.26.3 https://hardhat.org

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v5.4.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


// File contracts/interfaces/IEconomicModel.sol

// Original license: SPDX_License_Identifier: MIT
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
        uint256 instructorRate;   // 讲师分成比例 (默认85%)
        uint256 platformRate;     // 平台分成比例 (默认10%)
        uint256 referralRate;     // 推荐人分成比例 (默认5%)
    }

    // ==================== 事件定义 ====================

    /**
     * @dev 推荐关系建立事件
     */
    event ReferralSet(
        address indexed user,
        address indexed referrer
    );

    /**
     * @dev 推荐奖励发放事件
     */
    event ReferralRewardPaid(
        address indexed referrer,
        address indexed student,
        uint256 indexed courseId,
        uint256 amount
    );

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
        uint256 platformRate,
        uint256 referralRate
    );

    // ==================== 功能接口 ====================

    /**
     * @dev 设置推荐人
     */
    function setReferrer(address referrer) external;

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
     * @dev 获取推荐人
     */
    function getReferrer(address user) external view returns (address);

    /**
     * @dev 获取费率配置
     */
    function getFeeConfig() external view returns (FeeConfig memory);
}


// File contracts/interfaces/ICourseContract.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICourseContract
 * @dev 课程合约接口定义（包含经济模型功能）
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
        uint256 totalLessons; // 总课时数
        bool isPublished;    // 是否已发布
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

    // 推荐系统
    function setReferrer(address referrer) external;

    function getReferrer(address user) external view returns (address);

    function getReferralEarnings(address referrer) external view returns (uint256);

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


// File contracts/interfaces/IERC20.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC20
 * @dev 简化的ERC20接口，仅包含课程合约需要的方法
 */
interface IERC20 {
    /**
     * @dev 返回代币总供应量
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev 返回账户余额
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 转账代币到指定地址
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev 返回授权额度
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev 授权第三方使用代币
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev 第三方转账（需要预先授权）
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /**
     * @dev 转账事件
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev 授权事件
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File contracts/libraries/CourseManagement.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CourseManagement
 * @dev 课程管理库
 */
library CourseManagement {

    error EmptyTitle();
    error TitleTooLong();
    error InvalidPrice();
    error PriceTooHigh();
    error InvalidLessons();
    error TooManyLessons();

    /**
     * @dev 验证课程创建参数
     */
    function validateCourseParams(
        string memory title,
        uint256 price,
        uint256 totalLessons
    ) internal pure {
        if (bytes(title).length == 0) revert EmptyTitle();
        if (bytes(title).length > 100) revert TitleTooLong();
        if (price == 0) revert InvalidPrice();
        if (price >= 500 * 1e18) revert PriceTooHigh();
        if (totalLessons == 0) revert InvalidLessons();
        if (totalLessons > 1000) revert TooManyLessons();
    }

    /**
     * @dev 创建课程
     */
    function createCourse(
        mapping(uint256 => ICourseContract.Course) storage courses,
        uint256 courseId,
        string memory title,
        address instructor,
        uint256 price,
        uint256 totalLessons
    ) internal {
        courses[courseId] = ICourseContract.Course({
            id: courseId,
            title: title,
            instructor: instructor,
            price: price,
            totalLessons: totalLessons,
            isPublished: true
        });
    }

    /**
     * @dev 更新课程价格
     */
    function updatePrice(
        mapping(uint256 => ICourseContract.Course) storage courses,
        uint256 courseId,
        uint256 newPrice
    ) internal returns (uint256 oldPrice) {
        if (newPrice == 0) revert InvalidPrice();
        if (newPrice >= 500 * 1e18) revert PriceTooHigh();

        ICourseContract.Course storage course = courses[courseId];
        oldPrice = course.price;
        course.price = newPrice;
    }
}


// File contracts/libraries/PaymentDistributor.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;


/**
 * @title PaymentDistributor
 * @dev 支付分账处理库
 * @notice 负责将课程收入按比例分配给讲师、平台和推荐人
 */
library PaymentDistributor {

    // ==================== 错误定义 ====================

    error TransferFailed(address to, uint256 amount);
    error InvalidFeeConfig();

    // ==================== 分账逻辑 ====================

    /**
     * @dev 执行支付分账
     * @param token YD代币合约
     * @param student 学生地址
     * @param referrer 推荐人地址（可能为address(0)）
     * @param amount 总金额
     * @param config 费率配置
     * @return instructorAmount 讲师获得金额
     * @return platformAmount 平台获得金额
     * @return referralAmount 推荐人获得金额
     */
    function distributePayment(
        IERC20 token,
        address student,
        address /* instructor */,
        address /* platform */,
        address referrer,
        uint256 amount,
        IEconomicModel.FeeConfig memory config
    )
    internal
    returns (
        uint256 instructorAmount,
        uint256 platformAmount,
        uint256 referralAmount
    )
    {
        // 验证费率配置总和为100%
        _validateFeeConfig(config);

        // 计算各方金额
        if (referrer != address(0)) {
            // 有推荐人的情况
            referralAmount = (amount * config.referralRate) / 100;
            instructorAmount = (amount * config.instructorRate) / 100;
            platformAmount = amount - instructorAmount - referralAmount;
        } else {
            // 无推荐人的情况，推荐人的5%归讲师
            referralAmount = 0;
            instructorAmount = (amount * (config.instructorRate + config.referralRate)) / 100;
            platformAmount = amount - instructorAmount;
        }

        // 从学生账户转移代币到合约
        bool transferSuccess = token.transferFrom(student, address(this), amount);
        if (!transferSuccess) {
            revert TransferFailed(address(this), amount);
        }

        // 返回各方应得金额（实际转账由调用方处理，避免重入攻击）
        return (instructorAmount, platformAmount, referralAmount);
    }

    /**
     * @dev 执行代币转账
     * @param token YD代币合约
     * @param to 接收地址
     * @param amount 转账金额
     */
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        if (amount == 0) return;

        bool success = token.transfer(to, amount);
        if (!success) {
            revert TransferFailed(to, amount);
        }
    }

    /**
     * @dev 批量转账
     * @param token YD代币合约
     * @param recipients 接收地址数组
     * @param amounts 对应金额数组
     */
    function batchTransfer(
        IERC20 token,
        address[] memory recipients,
        uint256[] memory amounts
    ) internal {
        if (recipients.length != amounts.length) revert InvalidFeeConfig();

        for (uint256 i = 0; i < recipients.length; i++) {
            safeTransfer(token, recipients[i], amounts[i]);
        }
    }

    /**
     * @dev 计算退款金额（70%）
     * @param originalAmount 原始支付金额
     * @return 退款金额
     */
    function calculateRefundAmount(uint256 originalAmount)
    internal
    pure
    returns (uint256)
    {
        return (originalAmount * 70) / 100;
    }

    /**
     * @dev 计算手续费（30%）
     * @param originalAmount 原始支付金额
     * @return 手续费金额
     */
    function calculateRefundFee(uint256 originalAmount)
    internal
    pure
    returns (uint256)
    {
        return (originalAmount * 30) / 100;
    }

    // ==================== 内部验证函数 ====================

    /**
     * @dev 验证费率配置是否合法
     * @param config 费率配置
     */
    function _validateFeeConfig(IEconomicModel.FeeConfig memory config)
    private
    pure
    {
        uint256 totalRate = config.instructorRate + config.platformRate + config.referralRate;
        if (totalRate != 100) {
            revert InvalidFeeConfig();
        }
    }

    /**
     * @dev 验证地址是否有效
     * @param addr 要验证的地址
     */
    function isValidAddress(address addr) internal pure returns (bool) {
        return addr != address(0);
    }

    /**
     * @dev 计算百分比金额
     * @param amount 总金额
     * @param percentage 百分比（0-100）
     * @return 计算结果
     */
    function calculatePercentage(uint256 amount, uint256 percentage)
    internal
    pure
    returns (uint256)
    {
        if (percentage > 100) revert InvalidFeeConfig();
        return (amount * percentage) / 100;
    }
}


// File contracts/libraries/ProgressTracker.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

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
        if (totalLessons == 0) revert InvalidProgress();

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


// File contracts/libraries/PurchaseLogic.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;



/**
 * @title PurchaseLogic
 * @dev 购买逻辑库
 */
library PurchaseLogic {

    /**
     * @dev 记录购买信息
     */
    function recordPurchase(
        mapping(address => mapping(uint256 => bool)) storage hasPurchased,
        mapping(address => uint256[]) storage studentCourses,
        mapping(uint256 => address[]) storage courseStudents,
        mapping(uint256 => uint256) storage courseStudentCount,
        mapping(address => mapping(uint256 => uint256)) storage coursePrices,
        mapping(address => mapping(uint256 => uint256)) storage purchaseTimestamps,
        address student,
        uint256 courseId,
        uint256 price
    ) internal {
        hasPurchased[student][courseId] = true;
        studentCourses[student].push(courseId);
        courseStudents[courseId].push(student);
        courseStudentCount[courseId]++;
        coursePrices[student][courseId] = price;
        purchaseTimestamps[student][courseId] = block.timestamp;
    }

    /**
     * @dev 计算分账金额
     */
    function calculateDistribution(
        uint256 price,
        address referrer,
        IEconomicModel.FeeConfig memory config
    ) internal pure returns (
        uint256 instructorAmount,
        uint256 platformAmount,
        uint256 referralAmount
    ) {
        if (referrer != address(0)) {
            referralAmount = (price * config.referralRate) / 100;
            instructorAmount = (price * config.instructorRate) / 100;
            platformAmount = price - instructorAmount - referralAmount;
        } else {
            referralAmount = 0;
            instructorAmount = (price * (config.instructorRate + config.referralRate)) / 100;
            platformAmount = price - instructorAmount;
        }
    }

    /**
     * @dev 处理代币转账和分账
     */
    function handlePaymentTransfers(
        IERC20 token,
        address student,
        address platformAddress,
        address referrer,
        uint256 price,
        uint256 platformAmount,
        uint256 referralAmount
    ) internal {
        // 从学生账户转入合约
        bool transferSuccess = token.transferFrom(student, address(this), price);
        require(transferSuccess, "Transfer failed");

        // 转给平台
        PaymentDistributor.safeTransfer(token, platformAddress, platformAmount);

        // 转给推荐人
        if (referrer != address(0) && referralAmount > 0) {
            PaymentDistributor.safeTransfer(token, referrer, referralAmount);
        }
    }
}


// File contracts/libraries/ReferralLogic.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ReferralLogic
 * @dev 推荐系统逻辑库
 */
library ReferralLogic {

    error ReferrerAlreadySet();
    error SelfReferral();
    error InvalidReferrer();

    /**
     * @dev 设置推荐人
     */
    function setReferrer(
        mapping(address => address) storage referrers,
        mapping(address => address[]) storage referredUsers,
        mapping(address => uint256) storage referralCount,
        address user,
        address referrer
    ) internal {
        if (referrers[user] != address(0)) revert ReferrerAlreadySet();
        if (referrer == user) revert SelfReferral();
        if (referrer == address(0)) revert InvalidReferrer();

        referrers[user] = referrer;
        referredUsers[referrer].push(user);
        referralCount[referrer]++;
    }

    /**
     * @dev 记录推荐奖励
     */
    function recordReferralReward(
        mapping(address => uint256) storage referralEarnings,
        address referrer,
        uint256 amount
    ) internal {
        if (referrer != address(0) && amount > 0) {
            referralEarnings[referrer] += amount;
        }
    }
}


// File contracts/libraries/RefundLogic.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;


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
     * @dev 处理推荐人收益回退
     */
    function handleReferralRollback(
        mapping(address => uint256) storage referralEarnings,
        address referrer,
        uint256 originalAmount,
        uint256 referralRate
    ) internal {
        if (referrer != address(0)) {
            uint256 referralAmount = (originalAmount * referralRate) / 100;
            if (referralEarnings[referrer] >= referralAmount) {
                referralEarnings[referrer] -= referralAmount;
            }
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


// File contracts/libraries/WithdrawalLogic.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;


/**
 * @title WithdrawalLogic
 * @dev 提现逻辑库
 */
library WithdrawalLogic {

    error InsufficientEarnings();
    error CooldownActive();
    error TransferFailed();

    /**
     * @dev 执行提现
     */
    function executeWithdrawal(
        IERC20 token,
        mapping(address => IEconomicModel.InstructorEarnings) storage instructorEarnings,
        mapping(address => uint256[]) storage withdrawalHistory,
        mapping(address => uint256) storage lastWithdrawalTime,
        address instructor,
        uint256 minWithdrawalAmount,
        uint256 withdrawalCooldown
    ) internal returns (uint256 amount) {
        // 检查条件
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];
        if (earnings.pending < minWithdrawalAmount) revert InsufficientEarnings();
        if (block.timestamp < lastWithdrawalTime[instructor] + withdrawalCooldown) revert CooldownActive();

        // 更新状态
        amount = earnings.pending;
        earnings.withdrawn += amount;
        earnings.pending = 0;
        withdrawalHistory[instructor].push(block.timestamp);
        lastWithdrawalTime[instructor] = block.timestamp;

        // 转账
        if (!token.transfer(instructor, amount)) revert TransferFailed();
    }

    /**
     * @dev 记录收益
     */
    function recordEarnings(
        mapping(address => IEconomicModel.InstructorEarnings) storage instructorEarnings,
        address instructor,
        uint256 amount
    ) internal {
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];
        earnings.totalEarned += amount;
        earnings.pending += amount;
    }
}


// File contracts/modules/PurchaseModule.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;





/**
 * @title PurchaseModule
 * @dev 处理课程购买逻辑
 */
library PurchaseModule {
    event CoursePurchased(
        uint256 indexed courseId,
        address indexed student,
        address indexed instructor,
        uint256 price
    );

    struct PurchaseData {
        mapping(uint256 => ICourseContract.Course) courses;
        mapping(address => mapping(uint256 => bool)) hasPurchased;
        mapping(address => uint256[]) studentCourses;
        mapping(uint256 => address[]) courseStudents;
        mapping(uint256 => uint256) courseStudentCount;
        mapping(address => mapping(uint256 => uint256)) coursePrices;
        mapping(address => mapping(uint256 => IEconomicModel.LearningProgress)) progressData;
        mapping(address => address) referrers;
    }

    function executePurchase(
        PurchaseData storage data,
        IERC20 ydToken,
        uint256 courseId,
        address student,
        address platformAddress,
        IEconomicModel.FeeConfig memory feeConfig
    ) internal returns (uint256 instructorAmount, uint256 platformAmount, uint256 referralAmount) {
        ICourseContract.Course storage course = data.courses[courseId];
        uint256 price = course.price;

        require(ydToken.balanceOf(student) >= price, "Insufficient YD balance");

        (instructorAmount, platformAmount, referralAmount) = PaymentDistributor.distributePayment(
            ydToken,
            student,
            course.instructor,
            platformAddress,
            data.referrers[student],
            price,
            feeConfig
        );

        recordPurchase(data, student, courseId, price);
        ProgressTracker.initializeProgress(data.progressData, student, courseId, course.totalLessons);

        emit CoursePurchased(courseId, student, course.instructor, price);
    }

    function recordPurchase(
        PurchaseData storage data,
        address student,
        uint256 courseId,
        uint256 price
    ) internal {
        data.hasPurchased[student][courseId] = true;
        data.studentCourses[student].push(courseId);
        data.courseStudents[courseId].push(student);
        data.courseStudentCount[courseId]++;
        data.coursePrices[student][courseId] = price;
    }
}


// File contracts/modules/QueryModule.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title QueryModule
 * @dev 处理课程查询功能
 */
library QueryModule {
    function getInstructorCourses(
        mapping(uint256 => ICourseContract.Course) storage courses,
        uint256 totalCourses,
        address instructor
    ) internal view returns (uint256[] memory) {
        uint256[] memory tempResults = new uint256[](totalCourses);
        uint256 count = 0;

        for (uint256 i = 1; i <= totalCourses; i++) {
            if (courses[i].instructor == instructor) {
                tempResults[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tempResults[i];
        }
        return result;
    }

    function batchCheckAccess(
        mapping(address => mapping(uint256 => bool)) storage hasPurchased,
        mapping(address => mapping(uint256 => bool)) storage hasRefunded,
        uint256 totalCourses,
        address student,
        uint256[] memory courseIds
    ) internal view returns (bool[] memory) {
        bool[] memory results = new bool[](courseIds.length);
        for (uint256 i = 0; i < courseIds.length; i++) {
            uint256 courseId = courseIds[i];
            if (courseId > 0 && courseId <= totalCourses) {
                results[i] = hasPurchased[student][courseId] && !hasRefunded[student][courseId];
            } else {
                results[i] = false;
            }
        }
        return results;
    }
}


// File contracts/modules/ReferralModule.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ReferralModule
 * @dev 推荐奖励模块
 * @notice 管理用户推荐关系和推荐收益统计
 */
contract ReferralModule {

    // ==================== 自定义错误 ====================
    error ReferrerAlreadySet();
    error SelfReferral();
    error InvalidReferrer();

    // ==================== 状态变量 ====================

    mapping(address => address) public referrers;
    mapping(address => uint256) public referralEarnings;
    mapping(address => uint256) public referralCount;
    mapping(address => address[]) public referredUsers;

    // ==================== 事件定义 ====================

    event ReferralSet(address indexed user, address indexed referrer);
    event ReferralRewardPaid(
        address indexed referrer,
        address indexed student,
        uint256 indexed courseId,
        uint256 amount
    );

    // ==================== 修饰符 ====================

    modifier referrerNotSet(address user) {
        if (referrers[user] != address(0)) revert ReferrerAlreadySet();
        _;
    }

    modifier notSelfReferral(address user, address referrer) {
        if (referrer == user) revert SelfReferral();
        _;
    }

    modifier validReferrer(address referrer) {
        if (referrer == address(0)) revert InvalidReferrer();
        _;
    }

    // ==================== 核心功能 ====================

    /**
     * @dev 设置推荐人（只能设置一次）
     * @param referrer 推荐人地址
     */
    function setReferrer(address referrer)
    external
    virtual
    referrerNotSet(msg.sender)
    notSelfReferral(msg.sender, referrer)
    validReferrer(referrer)
    {
        referrers[msg.sender] = referrer;
        referredUsers[referrer].push(msg.sender);
        referralCount[referrer]++;

        emit ReferralSet(msg.sender, referrer);
    }

    /**
     * @dev 记录推荐奖励（内部调用）
     * @param referrer 推荐人地址
     * @param student 学生地址
     * @param courseId 课程ID
     * @param amount 奖励金额
     */
    function _recordReferralReward(
        address referrer,
        address student,
        uint256 courseId,
        uint256 amount
    ) internal {
        if (referrer != address(0) && amount > 0) {
            referralEarnings[referrer] += amount;
            emit ReferralRewardPaid(referrer, student, courseId, amount);
        }
    }

    // ==================== 查询功能 ====================

    /**
     * @dev 获取用户的推荐人
     * @param user 用户地址
     * @return 推荐人地址
     */
    function getReferrer(address user) external view virtual returns (address) {
        return referrers[user];
    }

    /**
     * @dev 获取推荐人的总收益
     * @param referrer 推荐人地址
     * @return 总收益金额
     */
    function getReferralEarnings(address referrer) external view virtual returns (uint256) {
        return referralEarnings[referrer];
    }

    /**
     * @dev 获取推荐人数统计
     * @param referrer 推荐人地址
     * @return 推荐人数
     */
    function getReferralCount(address referrer) external view returns (uint256) {
        return referralCount[referrer];
    }

    /**
     * @dev 获取推荐人的所有被推荐用户
     * @param referrer 推荐人地址
     * @return 被推荐用户地址数组
     */
    function getReferredUsers(address referrer) external view returns (address[] memory) {
        return referredUsers[referrer];
    }

    /**
     * @dev 检查用户是否有推荐人
     * @param user 用户地址
     * @return 是否有推荐人
     */
    function hasReferrer(address user) external view returns (bool) {
        return referrers[user] != address(0);
    }

    /**
     * @dev 批量查询推荐人
     * @param users 用户地址数组
     * @return 推荐人地址数组
     */
    function batchGetReferrers(address[] memory users)
    external
    view
    returns (address[] memory)
    {
        address[] memory results = new address[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            results[i] = referrers[users[i]];
        }
        return results;
    }

    /**
     * @dev 获取推荐关系详细信息
     * @param user 用户地址
     * @return referrer 推荐人地址
     * @return earnings 推荐人总收益
     * @return count 推荐人数
     */
    function getReferralInfo(address user)
    external
    view
    returns (
        address referrer,
        uint256 earnings,
        uint256 count
    )
    {
        referrer = referrers[user];
        earnings = referralEarnings[user];
        count = referralCount[user];
    }
}


// File contracts/modules/RefundModule.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;



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


// File contracts/modules/WithdrawalModule.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;


/**
 * @title WithdrawalModule
 * @dev 提现管理模块
 * @notice 管理讲师的收益记录和提现操作
 */
contract WithdrawalModule {

    // ==================== 自定义错误 ====================
    error InvalidToken();
    error InsufficientEarnings();
    error CooldownActive();
    error TransferFailed();

    // ==================== 状态变量 ====================

    IERC20 public ydToken;

    mapping(address => IEconomicModel.InstructorEarnings) public instructorEarnings;
    mapping(address => uint256[]) public withdrawalHistory;
    mapping(address => uint256) public lastWithdrawalTime;

    uint256 public minWithdrawalAmount = 10 * 1e18;
    uint256 public withdrawalCooldown = 1 days;

    // ==================== 事件定义 ====================

    event InstructorWithdrawal(
        address indexed instructor,
        uint256 amount,
        uint256 timestamp
    );

    event EarningsUpdated(
        address indexed instructor,
        uint256 totalEarned,
        uint256 pending
    );

    event MinWithdrawalAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event WithdrawalCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    // ==================== 构造函数 ====================

    constructor(address _ydToken) {
        if (_ydToken == address(0)) revert InvalidToken();
        ydToken = IERC20(_ydToken);
    }

    // ==================== 修饰符 ====================

    modifier hasPendingEarnings(address instructor) {
        if (instructorEarnings[instructor].pending < minWithdrawalAmount) revert InsufficientEarnings();
        _;
    }

    modifier cooldownPassed(address instructor) {
        if (block.timestamp < lastWithdrawalTime[instructor] + withdrawalCooldown) revert CooldownActive();
        _;
    }

    // ==================== 核心功能 ====================

    /**
     * @dev 记录讲师收益（内部调用）
     * @param instructor 讲师地址
     * @param amount 收益金额
     */
    function _recordEarnings(address instructor, uint256 amount) internal {
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        earnings.totalEarned += amount;
        earnings.pending += amount;

        emit EarningsUpdated(instructor, earnings.totalEarned, earnings.pending);
    }

    /**
     * @dev 讲师提现
     * @return amount 提现金额
     */
    function withdrawEarnings()
    external
    virtual
    hasPendingEarnings(msg.sender)
    cooldownPassed(msg.sender)
    returns (uint256 amount)
    {
        address instructor = msg.sender;
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        amount = earnings.pending;

        // 更新收益记录
        earnings.withdrawn += amount;
        earnings.pending = 0;

        // 记录提现历史
        withdrawalHistory[instructor].push(block.timestamp);
        lastWithdrawalTime[instructor] = block.timestamp;

        // 转账YD代币
        if (!ydToken.transfer(instructor, amount)) revert TransferFailed();

        emit InstructorWithdrawal(instructor, amount, block.timestamp);
        return amount;
    }

    // ==================== 查询功能 ====================

    /**
     * @dev 获取讲师收益信息
     * @param instructor 讲师地址
     * @return 收益信息结构体
     */
    function getInstructorEarnings(address instructor)
    external
    view
    virtual
    returns (IEconomicModel.InstructorEarnings memory)
    {
        return instructorEarnings[instructor];
    }

    /**
     * @dev 获取讲师待提现金额
     * @param instructor 讲师地址
     * @return 待提现金额
     */
    function getPendingEarnings(address instructor)
    external
    view
    returns (uint256)
    {
        return instructorEarnings[instructor].pending;
    }

    /**
     * @dev 获取讲师总收益
     * @param instructor 讲师地址
     * @return 总收益金额
     */
    function getTotalEarned(address instructor)
    external
    view
    returns (uint256)
    {
        return instructorEarnings[instructor].totalEarned;
    }

    /**
     * @dev 获取讲师已提现金额
     * @param instructor 讲师地址
     * @return 已提现金额
     */
    function getWithdrawn(address instructor)
    external
    view
    returns (uint256)
    {
        return instructorEarnings[instructor].withdrawn;
    }

    /**
     * @dev 获取提现历史
     * @param instructor 讲师地址
     * @return 提现时间戳数组
     */
    function getWithdrawalHistory(address instructor)
    external
    view
    returns (uint256[] memory)
    {
        return withdrawalHistory[instructor];
    }

    /**
     * @dev 检查是否可以提现
     * @param instructor 讲师地址
     * @return canWithdraw 是否可以提现
     * @return reason 不能提现的原因（空字符串表示可以提现）
     */
    function canWithdraw(address instructor)
    external
    view
    returns (bool, string memory reason)
    {
        IEconomicModel.InstructorEarnings storage earnings = instructorEarnings[instructor];

        if (earnings.pending < minWithdrawalAmount) {
            return (false, "Low");
        }

        if (block.timestamp < lastWithdrawalTime[instructor] + withdrawalCooldown) {
            return (false, "Wait");
        }

        return (true, "");
    }
}


// File contracts/CourseContract.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;
















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
