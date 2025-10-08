// SPDX-License-Identifier: MIT
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