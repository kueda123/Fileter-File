@echo off
setlocal enabledelayedexpansion

REM テスト用: 2つのファイルを指定して実行
set PS_SCRIPT="%~dp0Filter-File.ps1"
set ENCODING=UTF8NoBOM
set TARGET_EXTS=".csv", ".conf", ".xml", ".properties", ".txt"
set EXCLUDE_PATTERN="*_backup.*", "master_*", "*.old"
cd /d "%~dp0"

REM 除外リストファイルを読み込んで配列として作成
set DELETE_LIST=
set "LIST_FILE=%~dp0delete_servers.txt"
if exist "!LIST_FILE!" (
    REM 専用のPowerShellスクリプトを使用してリストを作成
    for /f "delims=" %%i in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0read_delete_list.ps1" -FilePath "!LIST_FILE!"') do (
        call set DELETE_LIST=%%i
    )
)

if "!DELETE_LIST!"=="" (
    echo [INFO] DELETE_LISTが空です
    echo [INFO] 直接実行します
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" ^
      -EncodingType UTF8NoBOM ^
      -TargetExtensions ".csv", ".conf", ".xml", ".properties", ".txt" ^
      -ExcludePattern "*_backup.*", "master_*", "*.old" ^
      "%~dp0test_input.csv" "%~dp0test_input.conf"
    set "PS_EXIT_CODE=%ERRORLEVEL%"
    echo [INFO] PowerShell終了コード: !PS_EXIT_CODE!
) else (
    echo [INFO] DELETE_LIST: !DELETE_LIST!
    REM DeleteListを一時ファイルに書き込んでから実行
    call set "TEMP_DELETE_LIST=%%TEMP%%\delete_list_%%RANDOM%%.txt"
    echo !DELETE_LIST! > "!TEMP_DELETE_LIST!"
    echo [INFO] TEMP_DELETE_LIST: !TEMP_DELETE_LIST!
    
    REM 複数ファイルを処理するため、配列として構築
    set "INPUT_PATHS=%~dp0test_input.csv,%~dp0test_input.conf"
    echo [INFO] INPUT_PATHS: !INPUT_PATHS!
    
    call set "LOG_FILE=%%TEMP%%\filter_file_%%RANDOM%%.log"
    call set "TEMP_PS_SCRIPT=%%TEMP%%\filter_exec_%%RANDOM%%.ps1"
    echo [INFO] LOG_FILE: !LOG_FILE!
    echo [INFO] TEMP_PS_SCRIPT: !TEMP_PS_SCRIPT!
    
    REM 一時PowerShellスクリプトを作成（専用スクリプトを使用）
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0create_temp_script.ps1" -TempDeleteList "!TEMP_DELETE_LIST!" -PsScript "!PS_SCRIPT!" -Encoding "%ENCODING%" -TargetExts "%TARGET_EXTS%" -ExcludePattern "%EXCLUDE_PATTERN%" -InputPaths "!INPUT_PATHS!" -OutputScript "!TEMP_PS_SCRIPT!"
    
    REM 一時PowerShellスクリプトを実行
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!TEMP_PS_SCRIPT!" > "!LOG_FILE!" 2>&1
    set "PS_EXIT_CODE=%ERRORLEVEL%"
    echo [INFO] PowerShell終了コード: !PS_EXIT_CODE!
    
    if exist "!TEMP_PS_SCRIPT!" (
        echo [INFO] 一時スクリプトファイルの内容:
        type "!TEMP_PS_SCRIPT!"
        del "!TEMP_PS_SCRIPT!" 2>nul
    )
    if exist "!TEMP_DELETE_LIST!" del "!TEMP_DELETE_LIST!" 2>nul
    
    if !PS_EXIT_CODE! NEQ 0 (
        echo.
        echo [ERROR] PowerShellスクリプトがエラーで終了しました。終了コード: !PS_EXIT_CODE!
        echo [ERROR] ログファイル: !LOG_FILE!
        if exist "!LOG_FILE!" (
            echo [INFO] ログファイルの内容:
            type "!LOG_FILE!"
        ) else (
            echo [ERROR] ログファイルが見つかりません
        )
        pause
        exit /b !PS_EXIT_CODE!
    )
    
    if exist "!LOG_FILE!" (
        echo [INFO] ログファイルの内容:
        type "!LOG_FILE!"
        del "!LOG_FILE!" 2>nul
    )
)

echo.
echo 処理が完了しました。
pause
endlocal
