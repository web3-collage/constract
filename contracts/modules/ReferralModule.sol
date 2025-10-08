// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IEconomicModel.sol";

/**
 * @title ReferralModule
 * @dev 推荐奖励模块
 * @notice 管理用户推荐关系和推荐收益统计
 */
contract ReferralModule {

    // ==================== 状态变量 ====================

    mapping(address => address) public referrers;           // 用户的推荐人
    mapping(address => uint256) public referralEarnings;    // 推荐人总收益
    mapping(address => uint256) public referralCount;       // 推荐人数统计
    mapping(address => address[]) public referredUsers;     // 推荐人的所有被推荐用户

    // ==================== 事件定义 ====================

    event ReferralSet(address indexed user, address indexed referrer);
    event ReferralRewardPaid(
        address indexed referrer,
        address indexed student,
        uint256 indexed courseId,
        uint256 amount
    );

    // ==================== 修饰符 ====================

    /**
     * @dev 验证推荐人尚未设置
     */
    modifier referrerNotSet(address user) {
        require(referrers[user] == address(0), "Referrer already set");
        _;
    }

    /**
     * @dev 验证不能自我推荐
     */
    modifier notSelfReferral(address user, address referrer) {
        require(referrer != user, "Cannot refer yourself");
        _;
    }

    /**
     * @dev 验证推荐人地址有效
     */
    modifier validReferrer(address referrer) {
        require(referrer != address(0), "Invalid referrer address");
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