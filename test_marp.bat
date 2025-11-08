
@echo off
setlocal

:: --- CONFIG ---
set PORT=3777
set TESTDIR=%TEMP%\marp_test
set TESTFILE=%TESTDIR%\slides.md

:: --- CLEANUP OLD TEST ---
if exist "%TESTDIR%" rd /s /q "%TESTDIR%"
mkdir "%TESTDIR%"

:: --- CREATE SIMPLE SLIDE ---
echo # Test Slide > "%TESTFILE%"
echo. >> "%TESTFILE%"
echo --- >> "%TESTFILE%"
echo # Slide 2 >> "%TESTFILE%"

:: --- CHECK MRP ---
where marp >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Marp CLI not found in PATH.
    echo Install it with: npm i -g @marp-team/marp-cli
    pause
    exit /b 1
)

:: --- START SERVER ---
echo Starting Marp server on port %PORT% ...
start "MarpServer" cmd /c "cd /d %TESTDIR% && set PORT=%PORT% && marp -s ."

:: --- WAIT A BIT ---
echo Waiting for Marp to start...
timeout /t 5 >nul

:: --- TEST CONNECTION ---
powershell -Command "(Invoke-WebRequest -UseBasicParsing http://127.0.0.1:%PORT%/slides.md).StatusCode" 2>nul | find "200" >nul
if errorlevel 1 (
    echo [FAIL] Marp server not responding on http://127.0.0.1:%PORT%
    echo Try running manually: 
    echo     marp -s %TESTDIR%
    echo or check firewall prompts.
) else (
    echo [OK] Marp server responded successfully!
    echo You can open: http://127.0.0.1:%PORT%/slides.md
)

pause
endlocal
