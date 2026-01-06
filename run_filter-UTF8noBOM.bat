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

REM --------------------------------------------------------
REM 実行処理 (変更不要)
REM --------------------------------------------------------
set PS_SCRIPT="%~dp0Filter-File.ps1"
cd /d "%~dp0"

REM 除外リストファイルを読み込んで配列として作成
set "DELETE_LIST="
set "LIST_FILE=%~dp0%DELETE_LIST_FILE%"
if exist "!LIST_FILE!" (
    REM 専用のPowerShellスクリプトを使用
    for /f "delims=" %%i in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0read_delete_list.ps1" -FilePath "!LIST_FILE!"') do (
        set "DELETE_LIST=%%i"
    )
)

if "!DELETE_LIST!"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File %PS_SCRIPT% ^
      -EncodingType %ENCODING% ^
      -TargetExtensions %TARGET_EXTS% ^
      -ExcludePattern %EXCLUDE_PATTERN% ^
      %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& %PS_SCRIPT% -EncodingType %ENCODING% -TargetExtensions %TARGET_EXTS% -ExcludePattern %EXCLUDE_PATTERN% -DeleteList '!DELETE_LIST!' -InputPaths '%*'"
)

if %ERRORLEVEL% NEQ 0 (
    echo エラーが発生しました。
    pause
    exit /b %ERRORLEVEL%
) else (
    echo 処理が完了しました。
    timeout /t 3 >nul
)
endlocal
