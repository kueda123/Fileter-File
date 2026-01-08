# run_filter-UTF8noBOM.bat リファレンス

## 1. 概要

本バッチファイルは、PowerShellスクリプト Filter-File.ps1 のラッパープログラムです。
バッチファイル内の「設定エリア」の属性値を変更することで、出力ファイルのエンコードや改行コードを制御し、様々な用途（Linux用、Excel用など）に対応させることができます。

## 2. 標準設定（Config）とパラメータ解説

以下は、配布時の標準ファイル run_filter-UTF8noBOM.bat に記述されている設定値です。
```batch
REM --- 1. CONFIGURATION (設定) ---
set "ENCODING=UTF8NoBOM"
set "LINE_ENDING=LF"
set "TARGET_EXTS=.csv,.conf,.xml,.properties,.txt"
set "EXCLUDE_PATTERN=*_backup.*,master_*,*.old"
set "DELETE_LIST_FILE=delete_servers.txt"
set "KEEP_LOG_ON_SUCCESS=0"
```

### 説明


| パラメータ名 | 説明 |
| :--- | :--- |
|ENCODING|出力ファイルの文字コードとBOMの有無を指定します。<br>- UTF8NoBOM: UTF-8 (BOMなし)<br>- UTF8BOM: UTF-8 (BOMあり)<br>- ShiftJIS: Shift-JIS (BOMなし) |
|LINE_ENDING|改行コードを指定します。<br>- LF: Linux/Unix系 (標準) <br>- CRLF: Windows系|
|TARGET_EXTS|処理対象とするファイルの拡張子（カンマ区切り）。|
|EXCLUDE_PATTERN|処理から除外するファイル名のパターン。<br>例: *_backup.*|
|DELETE_LIST_FILE|削除対象リストのファイル名。|
|KEEP_LOG_ON_SUCCESS|処理成功時にログを残すか (0:自動削除, 1:残す)。|


## 3. 技術仕様

### 処理ロジック (高速化)

大量の削除キーワードを高速に処理するため、内部でリストを正規表現 (Regex) のOR条件にコンパイルして一括判定を行っています。

これにより、ファイル内の行データに対するキーワード検索（delete_servers.txt の内容に基づく検索）が劇的に高速化されます。

ファイル名の除外判定（EXCLUDE_PATTERN）には、通常のワイルドカードマッチングが使用されます。

### ステータス判定

バッチファイルは PowerShell からの終了コード (Exit Code) を受け取り、動作を変化させます。
|Exit Code|状態|動作|
 :--- | :--- | :--- |
|0|正常終了|ログを削除(設定次第)し、5秒後にウィンドウを閉じる。|
|1|エラー|スクリプト実行エラー。<br>ウィンドウは閉じずに一時停止する|
|2|	警告|outputファイル重複、または削除リストが空の場合。<br>ウィンドウは閉じずに一時停止する。|

### UTF-8ログ対応
ログファイルは「UTF-8 (BOM付き)」で出力されます。これにより、特殊文字や日本語が含まれていても文字化けせずに確認が可能です


## 4. 用途別設定ガイド

### ① 標準設定：Linux / Webサーバー / 開発用

Linux環境での利用を前提とした標準設定です。
    • 設定値:

```batch
set "ENCODING=UTF8NoBOM"
set "LINE_ENDING=LF"
```

    • 用途:
        ○ Linuxの設定ファイル (.conf)、シェルスクリプト
        ○ Dockerの設定ファイル、Webサーバーログ
    • 解説:
        ○ UTF8NoBOM: BOMによる読み込みエラーを防ぎます。
        ○ LF: Linux標準の改行コードに統一します。Windows環境で作成されたファイルに含まれる CRLF も LF に変換されます。

### ② 応用設定A：Excel / レガシーシステム用

WindowsアプリやExcelでの利用を想定した設定です。
（推奨ファイル名: run_filter-SJIS.bat）
    • 設定値:
```batch
set "ENCODING=ShiftJIS"
set "LINE_ENDING=CRLF"
```

    • 用途:
        ○ Excel用CSV
        ○ Windowsバッチファイルから参照されるテキスト
    • 解説:
        ○ ShiftJIS: Excelでの文字化けを防ぎます。
        ○ CRLF: Windows標準の改行コードを使用し、メモ帳などの古いエディタでの表示崩れを防ぎます。

### ③ 応用設定B：特殊用途（BOM付きUTF-8）

BOMを必要とする特定のアプリケーション用です。
（推奨ファイル名: run_filter-UTF8BOM.bat）
    • 設定値:
```batch
set "ENCODING=UTF8BOM"
set "LINE_ENDING=CRLF"
```

    • 用途:
        ○ 多言語を含むCSVをExcelで開く場合
    • 解説:
Windowsアプリでの利用が前提となるため、通常は改行コードも CRLF とセットで使用します。
