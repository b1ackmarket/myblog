@echo off
setlocal

:: === 配置区域 ===
set REMOTE_DIR=/data/myblog
set DEVICE_IP=192.168.0.1

echo ==========================================
echo [0/4] Check ADB Connection
echo ==========================================

adb get-state >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Device not found. Trying to connect...
    adb disconnect >nul 2>&1
    adb connect %DEVICE_IP%
    
    echo [INFO] Waiting 5 seconds for handshake...
    timeout /t 5 /nobreak >nul
    
    adb get-state >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo [ERROR] Connect Timeout! 
        goto ERROR_HANDLER
    )
)
echo [SUCCESS] Device Connected!

echo.
echo ==========================================
echo [1/4] Step 1: Hugo Build
echo ==========================================
hugo --minify
if %errorlevel% neq 0 goto ERROR_HANDLER

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
if %errorlevel% neq 0 goto ERROR_HANDLER

echo [SUCCESS] Blog Deployed Successfully!

echo.
echo ==========================================
echo [4/4] Step 4: Sync to GitHub
echo ==========================================
echo [INFO] Adding files...
git add .

echo [INFO] Committing...
:: 简化提交信息，防止因日期格式问题导致闪退
git commit -m "Auto deploy update"

echo [INFO] Pushing to GitHub...
git push

if %errorlevel% == 0 (
    echo [SUCCESS] Code Synced to GitHub!
) else (
    echo [WARNING] Git Push finished (or nothing to commit).
)

:: === 成功流程结束，跳转到收尾 ===
goto END

:ERROR_HANDLER
echo.
echo ==========================================
echo [CRITICAL ERROR] Script Aborted!
echo Please check the error messages above.
echo ==========================================
goto END

:END
:: === 无论成功还是失败，都会执行这里 ===
echo.
echo [INFO] Disconnecting ADB...
adb disconnect %DEVICE_IP% >nul 2>&1

echo.
echo ==========================================
echo     Execution Finished.
echo     (You can close this window now)
echo ==========================================
pause