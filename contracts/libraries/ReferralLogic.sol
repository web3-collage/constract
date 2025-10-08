// SPDX-License-Identifier: MIT
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
