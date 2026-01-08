@echo off
setlocal EnableDelayedExpansion

REM ========================================================
REM  Filter Tool Launcher (Final Release)
REM  Enc: UTF8NoBOM / Line: LF / Auto-Close: 5sec
REM ========================================================

REM コンソールをUTF-8に設定 (文字化け防止)
chcp 65001 >nul

REM --- 1. CONFIGURATION (設定) ---
set "ENCODING=UTF8NoBOM"
set "LINE_ENDING=LF"
set "TARGET_EXTS=.csv,.conf,.xml,.properties,.txt"
set "EXCLUDE_PATTERN=*_backup.*,master_*,*.old"
set "DELETE_LIST_FILE=delete_servers.txt"

REM 成功時のログ削除設定 (0:削除する, 1:残す)
set "KEEP_LOG_ON_SUCCESS=0"


REM --- 2. INITIALIZATION (初期化) ---
cd /d "%~dp0"

set "PS_SCRIPT=%~dp0Filter-File.ps1"
if not exist "!PS_SCRIPT!" goto :NO_SCRIPT

set "LIST_PATH=%~dp0%DELETE_LIST_FILE%"
if not exist "!LIST_PATH!" goto :NO_LIST

if "%~1"=="" goto :NO_INPUT


REM --- 3. ARGUMENT BUILDER (引数構築) ---
set "INPUT_PATHS="
for %%a in (%*) do (
    if "!INPUT_PATHS!"=="" (
        set "INPUT_PATHS=%%a"
    ) else (
        set "INPUT_PATHS=!INPUT_PATHS!,%%a"
    )
)


REM --- 4. EXECUTION (実行) ---
for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"`) do set "TIMESTAMP=%%t"
set "LOG_FILE=%~dp0filter_file_!TIMESTAMP!.log"

echo [INFO] Processing...
echo [INFO] Log File: !LOG_FILE!

REM PowerShell実行
REM - Note: 出力はUTF-8(BOM付)でログ保存され、ExitCodeで結果を判定します
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" ^
  -EncodingType "%ENCODING%" ^
  -LineEnding "%LINE_ENDING%" ^
  -TargetExtensions "%TARGET_EXTS%" ^
  -ExcludePattern "%EXCLUDE_PATTERN%" ^
  -DeleteListPath "!LIST_PATH!" ^
  -InputPaths "!INPUT_PATHS!" > "!LOG_FILE!" 2>&1

set "PS_EXIT_CODE=!ERRORLEVEL!"
echo [INFO] Exit Code: !PS_EXIT_CODE!


REM --- 5. CHECK RESULT (判定) ---

REM A. 警告あり (ExitCode=2)
if !PS_EXIT_CODE! EQU 2 goto :WARNING_DETECTED

REM B. エラー発生 (ExitCode!=0)
if !PS_EXIT_CODE! NEQ 0 goto :ERROR

REM C. 念のための文字列チェック (Failsafe)
findstr /C:"[WARNING]" "!LOG_FILE!" >nul 2>&1
if !ERRORLEVEL! EQU 0 goto :WARNING_DETECTED


REM --- 6. SUCCESS (成功時処理) ---
if "!KEEP_LOG_ON_SUCCESS!"=="0" (
    echo [INFO] Success - Log file is deleted.
    del "!LOG_FILE!" 2>nul
) else (
    echo [INFO] Success - Log file is kept.
    type "!LOG_FILE!"
)

echo.
echo [INFO] Finished successfully.
echo        This window will close in 5 seconds...
timeout /t 5 >nul
exit /b


REM ========================================================
REM  HANDLERS (ハンドラ)
REM ========================================================

:WARNING_DETECTED
echo.
type "!LOG_FILE!"
echo.
echo [WARN] Warnings detected (File exists, Empty list, etc).
pause
exit /b

:ERROR
echo.
type "!LOG_FILE!"
echo.
echo [ERROR] Script Failed with Exit Code !PS_EXIT_CODE!.
pause
exit /b

:NO_INPUT
echo.
echo [INFO] No file dropped.
pause
exit /b

:NO_SCRIPT
echo.
echo [ERROR] Filter-File.ps1 NOT FOUND.
pause
exit /b

:NO_LIST
echo.
echo [ERROR] Delete List NOT FOUND.
pause
exit /b