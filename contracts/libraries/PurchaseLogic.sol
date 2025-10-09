// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";
import "../interfaces/IEconomicModel.sol";
import "./PaymentDistributor.sol";

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
     * @dev 计算分账金额（优化精度损失问题）
     * @notice 通过先扣除计算出的金额，最后用剩余金额分配给平台，避免精度损失
     */
    function calculateDistribution(
        uint256 price,
        address /* referrer */,
        IEconomicModel.FeeConfig memory config
    ) internal pure returns (
        uint256 instructorAmount,
        uint256 platformAmount,
        uint256 referralAmount
    ) {
        // 无推荐人系统，推荐人费率归零
        referralAmount = 0;
        instructorAmount = (price * config.instructorRate) / 100;
        // 平台获得剩余部分，避免精度损失
        platformAmount = price - instructorAmount;

        // 断言检查：确保总和等于价格
        assert(instructorAmount + platformAmount == price);
    }

    /**
     * @dev 处理代币转账和分账
     */
    function handlePaymentTransfers(
        IERC20 token,
        address student,
        address platformAddress,
        address /* referrer */,
        uint256 price,
        uint256 platformAmount,
        uint256 /* referralAmount */
    ) internal {
        // 从学生账户转入合约
        bool transferSuccess = token.transferFrom(student, address(this), price);
        require(transferSuccess, "Transfer failed");

        // 转给平台
        PaymentDistributor.safeTransfer(token, platformAddress, platformAmount);
    }
}
