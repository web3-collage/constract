// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ICourseContract.sol";

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
