#!/bin/bash

echo "🔨 正在生成 Remix 部署文件..."

# 生成 flattened 文件
npx hardhat flatten contracts/CourseContract.sol > CourseContract_flattened.sol

# 检查是否成功
if [ ! -f "CourseContract_flattened.sol" ]; then
    echo "❌ Flatten 失败"
    exit 1
fi

FILE_SIZE=$(wc -c < CourseContract_flattened.sol)
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "❌ 生成的文件太小，可能有错误"
    exit 1
fi

echo "✅ Flatten 成功！"
echo "📄 文件: CourseContract_flattened.sol"
echo "📊 大小: $(du -h CourseContract_flattened.sol | cut -f1)"

# 创建配置文件说明
cat > REMIX_QUICK_START.md << 'EOF'
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
EOF

echo ""
echo "📝 已创建快速开始指南: REMIX_QUICK_START.md"
echo ""
echo "🚀 下一步:"
echo "   1. 在 Remix 中上传 CourseContract_flattened.sol"
echo "   2. 上传 .remix-compiler.config.json"
echo "   3. 编译并部署"
echo ""
