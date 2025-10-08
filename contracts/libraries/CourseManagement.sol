// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ICourseContract.sol";

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
