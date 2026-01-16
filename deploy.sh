#!/bin/bash

# === 配置区域 ===
REMOTE_DIR="/data/myblog"
DEVICE_IP="192.168.0.1"

# 定义颜色，让输出好看点
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "[0/4] Check ADB Connection"
echo "=========================================="

# 尝试检查状态
adb get-state >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "[INFO] Connecting to $DEVICE_IP..."
    adb disconnect >/dev/null 2>&1
    adb connect $DEVICE_IP
    
    # 强制等待 5 秒握手，不管原来连没连上，稳一点
    echo "[INFO] Waiting 5 seconds for handshake..."
    sleep 5
fi

# 再次检查
adb get-state >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}[ERROR] Connect Failed! Script will continue but push might fail.${NC}"
else
    echo -e "${GREEN}[SUCCESS] Device Connected!${NC}"
fi

echo ""
echo "=========================================="
echo "[1/4] Step 1: Hugo Build"
echo "=========================================="
hugo --minify

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}[ERROR] Hugo Build Failed!${NC}"
    exit 1
fi

echo -e "${GREEN}[INFO] Hugo Build Success!${NC}"
echo ""

echo "=========================================="
echo "[2/4] Step 2: Clean Remote Files"
echo "=========================================="
adb shell "rm -rf $REMOTE_DIR/*"
echo "[INFO] Clean Command Sent."
echo ""

echo "=========================================="
echo "[3/4] Step 3: Push New Files"
echo "=========================================="
adb push public/. $REMOTE_DIR/

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}[ERROR] Push Failed!${NC}"
    exit 1
fi

echo -e "${GREEN}[SUCCESS] Blog Deployed!${NC}"
echo ""

echo "=========================================="
echo "[4/4] Step 4: Sync to GitHub"
echo "=========================================="
# 这里和 Windows 版保持一致，强制执行，不检测错误
echo "[INFO] Git Add..."
git add .

echo "[INFO] Git Commit..."
git commit -m "Auto deploy update"

echo "[INFO] Git Push..."
git push

echo ""
echo "=========================================="
echo "[INFO] Disconnecting ADB..."
adb disconnect $DEVICE_IP >/dev/null 2>&1
echo ""
echo -e "${GREEN}[DONE] All Finished.${NC}"
echo "=========================================="

# 模拟 Windows 的 pause，防止你双击运行脚本时窗口直接关掉
read -n 1 -s -r -p "Press any key to close..."
echo ""