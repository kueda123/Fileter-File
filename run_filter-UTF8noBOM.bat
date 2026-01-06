@echo off
setlocal

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


REM --------------------------------------------------------
REM 実行処理 (変更不要)
REM --------------------------------------------------------
set PS_SCRIPT="%~dp0Filter-File.ps1"
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File %PS_SCRIPT% ^
  -EncodingType %ENCODING% ^
  -TargetExtensions %TARGET_EXTS% ^
  -ExcludePattern %EXCLUDE_PATTERN% ^
  -InputPaths %*

if %ERRORLEVEL% NEQ 0 (
    echo エラーが発生しました。
    pause
    exit /b %ERRORLEVEL%
) else (
    echo 処理が完了しました。
    timeout /t 3 >nul
)
endlocal
