// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";
import "../interfaces/IEconomicModel.sol";

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