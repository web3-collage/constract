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
