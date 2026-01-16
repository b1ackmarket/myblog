@echo off
setlocal enabledelayedexpansion

:: === 配置区域 ===
set REMOTE_DIR=/data/myblog
set DEVICE_IP=192.168.0.1

echo ==========================================
echo [0/4] Check ADB Connection
echo ==========================================

:: 第一次检查
adb get-state >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Device not found. Trying to connect...
    
    :: 先断开清理一下旧状态
    adb disconnect >nul 2>&1
    
    :: 发起连接
    adb connect %DEVICE_IP%
    
    :: 等待 5 秒握手
    echo [INFO] Waiting 5 seconds for handshake...
    timeout /t 5 /nobreak >nul
    
    :: 第二次检查
    adb get-state >nul 2>&1
    if !errorlevel! neq 0 (
        echo.
        echo [ERROR] Connect Timeout! 
        echo The device did not respond in time.
        echo.
        pause
        exit /b
    ) else (
        echo [SUCCESS] Device Connected!
    )
) else (
    echo [INFO] Device is Online.
)

echo.
echo ==========================================
echo [1/4] Step 1: Hugo Build
echo ==========================================
hugo --minify

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build Failed! Check Hugo errors above.
    echo.
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

if %errorlevel% == 0 (
    echo.
    echo ==========================================
    echo [SUCCESS] Blog Deployed Successfully!
    echo ==========================================
) else (
    echo.
    echo ==========================================
    echo [ERROR] Push Failed!
    echo ==========================================
    pause
    exit /b
)

echo.
echo ==========================================
echo [4/4] Step 4: Sync to GitHub
echo ==========================================
echo [INFO] Adding files...
git add .

echo [INFO] Committing...
git commit -m "Auto deploy: %date% %time%"

echo [INFO] Pushing to GitHub...
git push

if %errorlevel% == 0 (
    echo.
    echo [SUCCESS] Code Synced to GitHub!
) else (
    echo.
    echo [WARNING] Git Push might have failed (or nothing to commit).
)

:: === 自动断开 ===
echo.
echo [INFO] Disconnecting ADB...
adb disconnect %DEVICE_IP% >nul 2>&1

echo.
echo All done. Press any key to exit.
pause >nul