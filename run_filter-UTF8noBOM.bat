@echo off
setlocal

REM ========================================================
REM  FINAL FIXED VERSION (With LineEnding Support)
REM ========================================================

REM 1. 設定エリア
set ENCODING=UTF8NoBOM
set LINE_ENDING=LF
set TARGET_EXTS=".csv,.conf,.xml,.properties,.txt"
set EXCLUDE_PATTERN="*_backup.*,master_*,*.old"
set DELETE_LIST_FILE=delete_servers.txt
set KEEP_LOG_ON_SUCCESS=0

REM 2. カレントディレクトリへの移動
cd /d "%~dp0"

REM 3. 必須ファイルの確認
set PS_SCRIPT="%~dp0Filter-File.ps1"
if not exist %PS_SCRIPT% goto :NO_SCRIPT

set LIST_PATH="%~dp0%DELETE_LIST_FILE%"
if not exist "%DELETE_LIST_FILE%" goto :NO_LIST

REM 4. 入力ファイルの確認（ドロップされたか？）
if "%~1"=="" goto :NO_INPUT

REM 5. 引数の構築
setlocal enabledelayedexpansion
set "INPUT_PATHS="
for %%a in (%*) do (
    if "!INPUT_PATHS!"=="" (
        set "INPUT_PATHS=%%a"
    ) else (
        set "INPUT_PATHS=!INPUT_PATHS!,%%a"
    )
)

REM 6. PowerShellの実行
for /f "tokens=*" %%t in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set TIMESTAMP=%%t
set LOG_FILE=%~dp0filter_file_!TIMESTAMP!.log

echo [INFO] Processing...
echo [INFO] Log File: !LOG_FILE!

powershell.exe -NoProfile -ExecutionPolicy Bypass -File %PS_SCRIPT% ^
  -EncodingType %ENCODING% ^
  -LineEnding %LINE_ENDING% ^
  -TargetExtensions "%TARGET_EXTS%" ^
  -ExcludePattern "%EXCLUDE_PATTERN%" ^
  -DeleteListPath !LIST_PATH! ^
  -InputPaths "!INPUT_PATHS!" > "!LOG_FILE!" 2>&1

set PS_EXIT_CODE=%ERRORLEVEL%
echo [INFO] Exit Code: !PS_EXIT_CODE!

if !PS_EXIT_CODE! NEQ 0 goto :ERROR

REM 7. 結果確認
findstr /C:"[WARNING]" "!LOG_FILE!" >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    type "!LOG_FILE!"
    echo.
    echo [WARN] Warnings detected. See log above.
    goto :END_PAUSE
)

if "!KEEP_LOG_ON_SUCCESS!"=="1" (
    echo [INFO] Success - Log file is kept.
    type "!LOG_FILE!"
) else (
    echo [INFO] Success - Log file is deleted.
    del "!LOG_FILE!" 2>nul
)

REM --------------------------------------------------------
REM  成功時：5秒後に自動クローズ
REM --------------------------------------------------------
echo.
echo [INFO] Finished successfully.
echo        This window will close in 5 seconds...
timeout /t 5 >nul
exit /b

REM ========================================================
REM  エラーハンドリング
REM ========================================================

:NO_INPUT
echo.
echo [INFO] No file dropped.
echo [INFO] Please DRAG ^& DROP target files onto this icon.
echo.
pause
exit /b

:NO_SCRIPT
echo.
echo [ERROR] Filter-File.ps1 NOT FOUND.
echo         Please ensure Filter-File.ps1 is in the same folder.
echo.
pause
exit /b

:NO_LIST
echo.
echo [ERROR] Delete List (%DELETE_LIST_FILE%) NOT FOUND.
echo         Please ensure the list file is in the same folder.
echo.
pause
exit /b

:ERROR
echo.
type "!LOG_FILE!"
echo.
echo [ERROR] Script Failed. See log above.
pause
exit /b

:END_PAUSE
echo.
echo [INFO] Finished with warnings/errors.
pause