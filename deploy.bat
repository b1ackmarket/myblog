@echo off
:: 移除 setlocal，减少环境干扰

:: === 配置区域 ===
set REMOTE_DIR=/data/myblog
set DEVICE_IP=192.168.0.1

echo ==========================================
echo [0/4] Check ADB Connection
echo ==========================================

adb get-state >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Connecting to %DEVICE_IP%...
    adb disconnect >nul 2>&1
    adb connect %DEVICE_IP%
    timeout /t 5 /nobreak >nul
)

adb get-state >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Connect Failed! Script will continue but may fail.
) else (
    echo [SUCCESS] Device Connected!
)

echo.
echo ==========================================
echo [1/4] Step 1: Hugo Build
echo ==========================================
hugo --minify
if %errorlevel% neq 0 (
    echo [ERROR] Hugo Build Failed!
    pause
    exit /b
)
echo [INFO] Hugo Build Success!

echo.
echo ==========================================
echo [2/4] Step 2: Clean Remote Files
echo ==========================================
adb shell "rm -rf %REMOTE_DIR%/*"
echo [INFO] Clean Command Sent.

echo.
echo ==========================================
echo [3/4] Step 3: Push New Files
echo ==========================================
adb push public/. %REMOTE_DIR%/
if %errorlevel% neq 0 (
    echo [ERROR] Push Failed!
    pause
    exit /b
)
echo [SUCCESS] Blog Deployed!

echo.
echo ==========================================
echo [4/4] Step 4: Sync to GitHub
echo ==========================================
git add .
git commit -m "Auto deploy update"
git push

echo.
echo ==========================================
echo [INFO] Disconnecting ADB...
adb disconnect %DEVICE_IP% >nul 2>&1
echo.
echo [DONE] All Finished.
echo ==========================================
pause