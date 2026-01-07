@echo off
setlocal enabledelayedexpansion

REM ========================================================
REM ■ ポリシー定義: メイン運用 (Linux連携用)
REM ========================================================

REM 1. 文字コード: BOMなしUTF-8
set ENCODING=UTF8NoBOM

REM 2. 処理許可する拡張子 (ホワイトリスト)
REM    これ以外（.exe, .zip, .xlsx 等）は全て無視します。
set TARGET_EXTS=".csv", ".conf", ".xml", ".properties", ".txt"

REM 3. 除外するファイルパターン (ブラックリスト)
REM    バックアップファイルや、処理したくない特定ファイルを除外します。
REM    (例: "master_*" で始まるファイルは触らない)
set EXCLUDE_PATTERN="*_backup.*", "master_*", "*.old"

REM 4. 除外リストファイル名
REM    削除対象サーバ名を記載したテキストファイル名
REM    （PS1スクリプトと同じフォルダに配置）
REM    変更する場合は、このBATファイルを別名で保管してください。
set DELETE_LIST_FILE=delete_servers.txt

REM 5. ログファイルの保持設定
REM    KEEP_LOG_ON_SUCCESS=1 の場合、正常終了時でもログファイルを保持します
REM    KEEP_LOG_ON_SUCCESS=0 の場合、正常終了時はログファイルを削除します（警告がある場合は保持）
REM    デフォルト: 1（保持）
set KEEP_LOG_ON_SUCCESS=1

REM --------------------------------------------------------
REM 実行処理 (変更不要)
REM --------------------------------------------------------
set PS_SCRIPT="%~dp0Filter-File.ps1"
cd /d "%~dp0"

REM 除外リストファイルを読み込んで配列として作成
set DELETE_LIST=
set "LIST_FILE=%~dp0%DELETE_LIST_FILE%"
if exist "!LIST_FILE!" (
    REM 専用のPowerShellスクリプトを使用してリストを作成
    for /f "delims=" %%i in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0read_delete_list.ps1" -FilePath "!LIST_FILE!"') do (
        set DELETE_LIST=%%i
    )
)

if "!DELETE_LIST!"=="" (
    REM 複数ファイルを処理するため、カンマ区切りで構築
    REM %*を個別の引数として処理
    set "INPUT_PATHS="
    for %%a in (%*) do (
        if "!INPUT_PATHS!"=="" (
            set "INPUT_PATHS=%%a"
        ) else (
            set "INPUT_PATHS=!INPUT_PATHS!,%%a"
        )
    )
    REM タイムスタンプ付きログファイル名を生成
    for /f "tokens=*" %%t in ('powershell.exe -NoProfile -Command "Get-Date -Format \"yyyyMMdd_HHmmss\""') do set "TIMESTAMP=%%t"
    set "LOG_FILE=%~dp0filter_file_!TIMESTAMP!.log"
    echo [INFO] ログファイル: !LOG_FILE!
    echo [INFO] INPUT_PATHS: !INPUT_PATHS!
    REM PowerShellスクリプトを実行（リダイレクトでログファイルに出力）
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File %PS_SCRIPT% ^
      -EncodingType %ENCODING% ^
      -TargetExtensions %TARGET_EXTS% ^
      -ExcludePattern %EXCLUDE_PATTERN% ^
      -InputPaths "!INPUT_PATHS!" > "!LOG_FILE!" 2>&1
    set PS_EXIT_CODE=%ERRORLEVEL%
    REM 出力が確実にフラッシュされ、ファイルがクローズされるまで待機
    timeout /t 2 /nobreak >nul 2>&1
    echo [INFO] PowerShell終了コード: !PS_EXIT_CODE!
    if !PS_EXIT_CODE! NEQ 0 (
        echo.
        echo [ERROR] PowerShellスクリプトがエラーで終了しました。終了コード: !PS_EXIT_CODE!
        echo [ERROR] ログファイル: !LOG_FILE!
        if exist "!LOG_FILE!" (
            type "!LOG_FILE!"
        ) else (
            echo [ERROR] ログファイルが見つかりません
        )
        echo.
        echo [INFO] ログファイルは削除されません: !LOG_FILE!
        pause
        exit /b !PS_EXIT_CODE!
    )
    echo.
    echo [DEBUG] ログファイルの存在確認: !LOG_FILE!
    if exist "!LOG_FILE!" (
        echo [DEBUG] ログファイルが存在します
        echo [DEBUG] ログファイルのフルパス: %~dp0filter_file_!TIMESTAMP!.log
        echo.
        echo [INFO] ログファイル: !LOG_FILE!
        echo.
        type "!LOG_FILE!"
        REM 警告が含まれている場合はpause
        findstr /C:"[WARNING]" "!LOG_FILE!" >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            echo.
            echo [WARN] 警告が検出されました。上記の警告を確認してください。
            echo [INFO] ログファイルは削除されません: !LOG_FILE!
            pause
        ) else (
            if "!KEEP_LOG_ON_SUCCESS!"=="1" (
                echo.
                echo [INFO] 正常終了しました。ログファイルを保持します: !LOG_FILE!
            ) else (
                echo.
                echo [INFO] 正常終了しました。ログファイルを削除します: !LOG_FILE!
                REM ファイルが完全にクローズされるまで待機
                timeout /t 1 /nobreak >nul 2>&1
                del !LOG_FILE! 2>nul
            )
            echo [DEBUG] 正常終了時のデバッグ: pauseを実行します
            pause
        )
    ) else (
        echo [DEBUG] ログファイルが存在しません
        echo [DEBUG] ログファイルのフルパス: %~dp0filter_file_!TIMESTAMP!.log
        echo.
        echo [WARN] ログファイルが作成されていません: !LOG_FILE!
        echo [WARN] PowerShellスクリプトの出力がリダイレクトされていない可能性があります。
        echo [DEBUG] 正常終了時のデバッグ: pauseを実行します
        pause
    )
) else (
    REM DeleteListを一時ファイルに書き込んでから実行
    call set "TEMP_DELETE_LIST=%%TEMP%%\delete_list_%%RANDOM%%.txt"
    echo !DELETE_LIST! > "!TEMP_DELETE_LIST!"
    REM 複数ファイルを処理するため、カンマ区切りで構築
    REM %*を個別の引数として処理
    set "INPUT_PATHS="
    for %%a in (%*) do (
        if "!INPUT_PATHS!"=="" (
            set "INPUT_PATHS=%%a"
        ) else (
            set "INPUT_PATHS=!INPUT_PATHS!,%%a"
        )
    )
    REM タイムスタンプ付きログファイル名を生成
    for /f "tokens=*" %%t in ('powershell.exe -NoProfile -Command "Get-Date -Format \"yyyyMMdd_HHmmss\""') do set "TIMESTAMP=%%t"
    set "LOG_FILE=%~dp0filter_file_!TIMESTAMP!.log"
    call set "TEMP_PS_SCRIPT=%%TEMP%%\filter_exec_%%RANDOM%%.ps1"
    echo [INFO] ログファイル: !LOG_FILE!
    echo [INFO] INPUT_PATHS: !INPUT_PATHS!
    REM 一時PowerShellスクリプトを作成（専用スクリプトを使用）
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0create_temp_script.ps1" -TempDeleteList "!TEMP_DELETE_LIST!" -PsScript "!PS_SCRIPT!" -Encoding "%ENCODING%" -TargetExts "%TARGET_EXTS%" -ExcludePattern "%EXCLUDE_PATTERN%" -InputPaths "!INPUT_PATHS!" -OutputScript "!TEMP_PS_SCRIPT!"
    REM 一時PowerShellスクリプトを実行
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!TEMP_PS_SCRIPT!" > "!LOG_FILE!" 2>&1
    set PS_EXIT_CODE=%ERRORLEVEL%
    REM 出力が確実にフラッシュされ、ファイルがクローズされるまで待機
    timeout /t 2 /nobreak >nul 2>&1
    if exist "!TEMP_PS_SCRIPT!" del "!TEMP_PS_SCRIPT!" 2>nul
    echo [INFO] PowerShell終了コード: !PS_EXIT_CODE!
    if exist "!TEMP_DELETE_LIST!" del "!TEMP_DELETE_LIST!" 2>nul
    if !PS_EXIT_CODE! NEQ 0 (
        echo.
        echo [ERROR] PowerShellスクリプトがエラーで終了しました。終了コード: !PS_EXIT_CODE!
        echo [ERROR] ログファイル: !LOG_FILE!
        if exist "!LOG_FILE!" (
            type "!LOG_FILE!"
        ) else (
            echo [ERROR] ログファイルが見つかりません
        )
        echo.
        echo [INFO] ログファイルは削除されません: !LOG_FILE!
        pause
        exit /b !PS_EXIT_CODE!
    )
    echo.
    echo [DEBUG] ログファイルの存在確認: !LOG_FILE!
    echo [DEBUG] ログファイルのフルパス: %~dp0filter_file_!TIMESTAMP!.log
    if exist "!LOG_FILE!" (
        echo [DEBUG] ログファイルが存在します
        echo.
        echo [INFO] ログファイル: !LOG_FILE!
        echo.
        type "!LOG_FILE!"
        REM 警告が含まれている場合はpause
        findstr /C:"スキップ [既存ファイル]" "!LOG_FILE!" >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            echo.
            echo [WARN] 既存ファイルが検出されました。上記の警告を確認してください。
            echo [INFO] ログファイルは削除されません: !LOG_FILE!
            pause
        ) else (
            if "!KEEP_LOG_ON_SUCCESS!"=="1" (
                echo.
                echo [INFO] 正常終了しました。ログファイルを保持します: !LOG_FILE!
            ) else (
                echo.
                echo [INFO] 正常終了しました。ログファイルを削除します: !LOG_FILE!
                REM ファイルが完全にクローズされるまで待機
                timeout /t 1 /nobreak >nul 2>&1
                del "!LOG_FILE!" 2>nul
            )
            echo [DEBUG] 正常終了時のデバッグ: pauseを実行します
            pause
        )
    ) else (
        echo [DEBUG] ログファイルが存在しません
        echo.
        echo [WARN] ログファイルが作成されていません: !LOG_FILE!
        echo [WARN] PowerShellスクリプトの出力がリダイレクトされていない可能性があります。
        echo [DEBUG] 正常終了時のデバッグ: pauseを実行します
        pause
    )
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] エラーが発生しました。終了コード: %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
) else (
    echo.
    echo 処理が完了しました。
    timeout /t 3 >nul
)
endlocal
