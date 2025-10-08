# Remix 快速部署

## 步骤 1: 上传文件

将以下文件上传到 Remix:
- `CourseContract_flattened.sol` (合约文件)
- `.remix-compiler.config.json` (配置文件)

## 步骤 2: 配置编译器

在 Solidity Compiler 标签:

### 方法 A: 使用配置文件
Remix 会自动检测 `.remix-compiler.config.json`

### 方法 B: 手动输入
在 "Advanced Configurations" 中输入:
```json
{
  "optimizer": {
    "enabled": true,
    "runs": 1
  },
  "viaIR": true
}
```

## 步骤 3: 编译

1. 选择 Solidity 版本: `0.8.28`
2. 点击 "Compile CourseContract_flattened.sol"
3. 等待编译完成

## 步骤 4: 检查大小

编译成功后，查看:
- ✅ Bytecode size 应该在 23-24KB
- ✅ 无 "exceeds 24576 bytes" 警告

## 步骤 5: 部署

1. 切换到 "Deploy & Run Transactions" 标签
2. 选择环境 (Injected Provider for MetaMask)
3. 填入构造函数参数:
   - `_ydToken`: YD Token 合约地址
   - `_platformAddress`: 平台收款地址
4. 点击 "Deploy"

## 注意事项

⚠️ **重要**: 必须启用 `viaIR: true`，否则合约会超过 24KB 限制！

如果遇到问题，查看 `REMIX_DEPLOYMENT.md` 获取详细故障排查指南。
