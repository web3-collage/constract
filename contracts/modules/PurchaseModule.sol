// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";
import "../interfaces/ICourseContract.sol";
import "../interfaces/IEconomicModel.sol";
import "../libraries/PaymentDistributor.sol";
import "../libraries/ProgressTracker.sol";

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
