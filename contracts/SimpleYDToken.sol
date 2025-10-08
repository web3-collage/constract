// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IERC20.sol";

/**
 * @title SimpleYDToken
 * @dev 简化版YD代币合约，用于测试和极简版实现
 */
contract SimpleYDToken is IERC20 {

    // ==================== 状态变量 ====================
    uint256 public constant EXCHANGE_RATE = 4000;

    string public constant name = "Yideng Token";
    string public constant symbol = "YD";
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    address public owner;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ==================== 修饰符 ====================

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // ==================== 构造函数 ====================

    constructor() {
        owner = msg.sender;
        _totalSupply = 1000000 * 10**decimals; // 初始发行100万YD
        _balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }

    // ==================== ERC20标准功能 ====================

    /**
     * @dev 返回代币总供应量
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev 返回账户余额
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev 转账代币
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        address from = msg.sender;
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev 查询授权额度
     */
    function allowance(address ownerAddr, address spender) public view override returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    /**
     * @dev 授权第三方使用代币
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        address ownerAddr = msg.sender;
        _approve(ownerAddr, spender, amount);
        return true;
    }

    /**
     * @dev 第三方转账
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // ==================== 内部函数 ====================
    /**
     * @dev 用户可以用ETH兑换YD代币
     * 兑换比例：1 ETH = 4000 YD
     */
    function exchangeETHForTokens() external payable {
        require(msg.value > 0, "Must send ETH to exchange");

        uint256 tokenAmount = msg.value * EXCHANGE_RATE;

        _transfer(owner, msg.sender, tokenAmount);
    }

    /**
     * @dev 内部转账函数
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    /**
     * @dev 内部授权函数
     */
    function _approve(address ownerAddr, address spender, uint256 amount) internal {
        require(ownerAddr != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");

        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    /**
     * @dev 内部消费授权函数
     */
    function _spendAllowance(address ownerAddr, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(ownerAddr, spender);
        require(currentAllowance >= amount, "Insufficient allowance");

        _approve(ownerAddr, spender, currentAllowance - amount);
    }

    // ==================== 管理员功能 ====================

    /**
     * @dev 铸造新代币（仅限owner）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Mint to zero address");

        _totalSupply += amount;
        _balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    /**
     * @dev 批量分发代币（测试用）
     * @param recipients 接收者地址数组
     * @param amounts 对应的金额数组
     */
    function batchTransfer(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

    /**
     * @dev 转移所有权
     * @param newOwner 新的所有者地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}