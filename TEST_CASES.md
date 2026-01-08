# テストケース解説

本ドキュメントは、Filter-File.ps1のテストケースについて説明します。

## テスト環境

### 削除リスト（delete_servers.txt）

すべてのテストケースで共通して使用される削除リストです。

```
SERVER1
server2
SERVER3
test-server
PROD-SERVER
```

**注意事項：**
- 大文字小文字が混在しています（`SERVER1`、`server2`など）
- 正規表現は大文字小文字を区別するため、`SERVER1`と`server1`は別のキーワードとして扱われます
- ハイフン（`-`）を含むキーワード（`test-server`、`PROD-SERVER`）も正しく処理されます

### テストファイルの構成

- **入力ファイル**: ルートディレクトリの `test_input_*.csv` / `test_input_*.conf`
- **期待値ファイル**: `expected/test_input_*.csv` / `expected/test_input_*.conf`
- **出力先**: 各入力ファイルと同じディレクトリの `output/` フォルダ

---

## テストケース一覧

### 1. 基本フィルタリングテスト

#### 1.1 test_input.csv / test_input.conf

**目的**: 基本的なフィルタリング機能を検証します。

**入力ファイル**: `test_input.csv`
```csv
hostname,ip,status
server1.example.com,192.168.1.10,active
server2.example.com,192.168.1.20,active
server3.example.com,192.168.1.30,active
web-server.example.com,192.168.1.40,active
db-server.example.com,192.168.1.50,active
test-server.example.com,192.168.1.60,active
prod-server.example.com,192.168.1.70,active
app-server.example.com,192.168.1.80,active
```

**期待値**: `expected/test_input.csv`
```csv
hostname,ip,status
web-server.example.com,192.168.1.40,active
db-server.example.com,192.168.1.50,active
app-server.example.com,192.168.1.80,active
```

**検証ポイント**:
- `server1.example.com` → 削除（`SERVER1`にマッチ）
- `server2.example.com` → 削除（`server2`にマッチ）
- `server3.example.com` → 削除（`SERVER3`にマッチ）
- `test-server.example.com` → 削除（`test-server`にマッチ）
- `prod-server.example.com` → 削除（`PROD-SERVER`にマッチ）
- ヘッダー行は保持される
- マッチしない行（`web-server`、`db-server`、`app-server`）は保持される

**入力ファイル**: `test_input.conf`
```conf
# Configuration file
server1.example.com:8080
server2.example.com:8080
server3.example.com:8080
web-server.example.com:8080
db-server.example.com:8080
test-server.example.com:8080
prod-server.example.com:8080
app-server.example.com:8080
```

**期待値**: `expected/test_input.conf`
```conf
# Configuration file
web-server.example.com:8080
db-server.example.com:8080
app-server.example.com:8080
```

**検証ポイント**:
- CSVファイルと同様のフィルタリングが動作する
- コメント行（`#`で始まる行）は保持される

---

### 2. ヘッダー行の処理テスト

#### 2.1 test_input_header_delete.csv

**目的**: ヘッダー行に削除対象のキーワードが含まれる場合の動作を検証します。

**入力ファイル**: `test_input_header_delete.csv`
```csv
SERVER1,ip,status
server1.example.com,192.168.1.10,active
server2.example.com,192.168.1.20,active
web-server.example.com,192.168.1.40,active
```

**期待値**: `expected/test_input_header_delete.csv`
```csv
web-server.example.com,192.168.1.40,active
```

**検証ポイント**:
- ヘッダー行 `SERVER1,ip,status` は削除される（`SERVER1`にマッチ）
- データ行の `server1.example.com` と `server2.example.com` も削除される
- マッチしない行のみが残る

**重要な動作**:
- ヘッダー行もデータ行と同様にフィルタリング対象となります
- ヘッダー行が削除された場合、出力ファイルにはヘッダー行が含まれません

#### 2.2 test_input_header_server1.csv

**目的**: ヘッダー行に`SERVER1`が含まれるが、データ行にも削除対象が含まれる場合の動作を検証します。

**入力ファイル**: `test_input_header_server1.csv`
```csv
SERVER1,ip,status
server1.example.com,192.168.1.10,active
server2.example.com,192.168.1.20,active
web-server.example.com,192.168.1.40,active
```

**期待値**: `expected/test_input_header_server1.csv`
```csv
web-server.example.com,192.168.1.40,active
```

**検証ポイント**:
- ヘッダー行 `SERVER1,ip,status` は削除される（`SERVER1`にマッチ）
- データ行の `server1.example.com` は削除される（`SERVER1`にマッチ）
- `server2.example.com` は削除される（`server2`にマッチ）
- マッチしない行（`web-server.example.com`）のみが残る

**重要な動作**:
- ヘッダー行が削除された場合、出力ファイルにはヘッダー行が含まれません
- すべての削除対象が削除され、マッチしないデータ行のみが残ります

---

### 3. 改行コード・文字コードのテスト

#### 3.1 test_input_crlf_bom.csv / test_input_crlf_bom.conf

**目的**: CRLF改行コードとBOM（Byte Order Mark）を含むファイルの処理を検証します。また、先頭データ行（ヘッダー行の次）に削除対象のサーバーデータが含まれるケースも検証します。

**入力ファイル**: `test_input_crlf_bom.csv`
- **文字コード**: UTF-8 BOM付き
- **改行コード**: CRLF（`\r\n`）

```csv
hostname,ip,status
SERVER1.example.com,192.168.1.10,active
server2.example.com,192.168.1.20,active
web-server.example.com,192.168.1.40,active
```

**期待値**: `expected/test_input_crlf_bom.csv`
```csv
hostname,ip,status
web-server.example.com,192.168.1.40,active
```

**検証ポイント**:
- CRLF改行コード（`\r\n`）を含むファイルを正しく読み込める
- BOM付きUTF-8ファイルを正しく処理できる
- 先頭データ行（`SERVER1.example.com`）が正しく削除される
- フィルタリング機能は正常に動作する
- 出力は標準設定（UTF-8 BOMなし、LF改行）で生成される

**入力ファイル**: `test_input_crlf_bom.conf`
- **文字コード**: UTF-8 BOM付き
- **改行コード**: CRLF（`\r\n`）

```conf
# Configuration file
SERVER1.example.com:8080
server2.example.com:8080
web-server.example.com:8080
```

**期待値**: `expected/test_input_crlf_bom.conf`
```conf
# Configuration file
web-server.example.com:8080
```

**検証ポイント**:
- confファイルでも同様にCRLF+BOMを処理できる
- コメント行（`#`で始まる行）は保持される

#### 3.2 test_input_lf.csv / test_input_lf.conf

**目的**: LF改行コードのみのファイルの処理を検証します。

**入力ファイル**: `test_input_lf.csv`
```csv
hostname,ip,status
server1.example.com,192.168.1.10,active
server2.example.com,192.168.1.20,active
server3.example.com,192.168.1.30,active
web-server.example.com,192.168.1.40,active
db-server.example.com,192.168.1.50,active
test-server.example.com,192.168.1.60,active
prod-server.example.com,192.168.1.70,active
app-server.example.com,192.168.1.80,active
```

**期待値**: `expected/test_input_lf.csv`
```csv
hostname,ip,status
web-server.example.com,192.168.1.40,active
db-server.example.com,192.168.1.50,active
app-server.example.com,192.168.1.80,active
```

**検証ポイント**:
- LF改行コード（`\n`）のみのファイルを正しく読み込める
- フィルタリング機能は正常に動作する
- 出力は標準設定（UTF-8 BOMなし、LF改行）で生成される

**入力ファイル**: `test_input_lf.conf`
```conf
# Configuration file
server1.example.com:8080
server2.example.com:8080
server3.example.com:8080
web-server.example.com:8080
db-server.example.com:8080
test-server.example.com:8080
prod-server.example.com:8080
app-server.example.com:8080
```

**期待値**: `expected/test_input_lf.conf`
```conf
# Configuration file
web-server.example.com:8080
db-server.example.com:8080
app-server.example.com:8080
```

**検証ポイント**:
- confファイルでも同様にLF改行を処理できる

---

## テスト実行方法

### 手動テスト

1. テスト対象のファイルを `run_filter-UTF8noBOM.bat` にドラッグ＆ドロップ
2. `output/` フォルダに生成されたファイルを確認
3. `expected/` フォルダの期待値ファイルと比較

### 自動テスト（推奨）

PowerShellスクリプトを使用して自動テストを実行できます：

```powershell
# すべてのテストケースを実行
$testFiles = @(
    "test_input.csv",
    "test_input.conf",
    "test_input_header_delete.csv",
    "test_input_header_server1.csv",
    "test_input_crlf_bom.csv",
    "test_input_crlf_bom.conf",
    "test_input_lf.csv",
    "test_input_lf.conf"
)

foreach ($file in $testFiles) {
    Write-Host "Testing: $file"
    # テスト実行と比較処理
}
```

---

## 検証すべき重要なポイント

### 1. 大文字小文字の区別
- `SERVER1` と `server1` は別のキーワードとして扱われる
- 削除リストに `SERVER1` がある場合、`server1.example.com` は削除されない（大文字小文字が一致しないため）

### 2. 部分マッチ
- キーワードは行内のどこに出現してもマッチする
- 例：`test-server.example.com` は `test-server` にマッチ

### 3. 特殊文字のエスケープ
- ハイフン（`-`）などの特殊文字は正規表現でエスケープされる
- `test-server` と `PROD-SERVER` は正しく処理される

### 4. コメント行の保持
- `#` で始まる行（コメント行）は削除リストのフィルタリング対象外
- ただし、コメント行に削除キーワードが含まれていれば削除される

### 5. 改行コードの統一
- 入力ファイルの改行コード（CRLF/LF）に関わらず、出力は設定に従って統一される
- 標準設定では LF 改行で出力される

---

## トラブルシューティング

### テストが失敗する場合

1. **出力ファイルが生成されない**
   - `delete_servers.txt` が存在するか確認
   - ファイルパスに問題がないか確認

2. **期待値と一致しない**
   - 削除リストの内容を確認
   - 大文字小文字の違いを確認
   - 改行コードの違いを確認（バイナリ比較ツールを使用）

3. **一部の行が削除されない**
   - 削除リストのキーワードと実際の行の内容を比較
   - スペースやタブなどの見えない文字がないか確認

---

## テストケースの追加

新しいテストケースを追加する場合：

1. 入力ファイルを `test_input_<ケース名>.csv` または `test_input_<ケース名>.conf` として作成
2. 期待値ファイルを `expected/test_input_<ケース名>.csv` または `expected/test_input_<ケース名>.conf` として作成
3. 本ドキュメントにテストケースの説明を追加
