<#
.SYNOPSIS
    ドラッグ＆ドロップ対応：ファイルフィルタリングツール

.DESCRIPTION
    バッチファイルから指定された「拡張子ホワイトリスト」と「除外ファイルパターン」に基づき、
    安全にテキスト処理を行います。指定外の拡張子やバイナリファイルはブロックします。

.PARAMETER InputPaths
    処理対象のファイルパスまたはフォルダパス
.PARAMETER EncodingType
    文字コード指定 ("UTF8NoBOM", "UTF8BOM", "Shift_JIS")
.PARAMETER TargetExtensions
    処理を許可する拡張子のリスト（ホワイトリスト）。例: ".csv", ".conf"
.PARAMETER ExcludePattern
    処理から除外するファイル名のパターン（ブラックリスト）。例: "*_backup.*", "test_*"
.PARAMETER DeleteList
    削除リスト
#>
param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$InputPaths,

    [string]$EncodingType = "UTF8NoBOM",

    [string[]]$TargetExtensions = @(".csv", ".conf", ".xml"),

    [string[]]$ExcludePattern = @(),

    [string[]]$DeleteList
)

# -------------------------------------------------------------
# 1. エンコーディング設定
# -------------------------------------------------------------
$encObj = $null
$encNameDisplay = ""

switch ($EncodingType.ToUpper()) {
    "UTF8BOM" {
        $encObj = New-Object System.Text.UTF8Encoding($true)
        $encNameDisplay = "UTF-8 (with BOM)"
    }
    "SHIFT_JIS" {
        $encObj = [System.Text.Encoding]::GetEncoding(932)
        $encNameDisplay = "Shift_JIS (CP932)"
    }
    "SJIS" {
        $encObj = [System.Text.Encoding]::GetEncoding(932)
        $encNameDisplay = "Shift_JIS (CP932)"
    }
    Default {
        $encObj = New-Object System.Text.UTF8Encoding($false)
        $encNameDisplay = "UTF-8 (No BOM)"
    }
}

# 拡張子の正規化（比較用）
$validExts = $TargetExtensions | ForEach-Object { $_.Trim().ToLower() }

Write-Host "=================================================="
Write-Host " エンコーディング : $encNameDisplay"
Write-Host " 対象拡張子       : $($validExts -join ', ')"
if ($ExcludePattern.Count -gt 0) {
    Write-Host " 除外パターン     : $($ExcludePattern -join ', ')"
}
Write-Host "=================================================="

# -------------------------------------------------------------
# 2. 共通設定（削除リスト読み込み）
# -------------------------------------------------------------
$ScriptBase = $PSScriptRoot
if ($null -eq $DeleteList -or $DeleteList.Count -eq 0) {
    $dlPath = Join-Path $ScriptBase "delete_servers.txt"
    if (Test-Path $dlPath) {
        $DeleteList = Get-Content $dlPath -Encoding UTF8 | 
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim().ToUpper() }
    } else {
        $DeleteList = @()
    }
}

# -------------------------------------------------------------
# 3. 内部関数: 単一ファイルの処理
# -------------------------------------------------------------
function Process-SingleFile {
    param($TargetFile)

    $fileName = [System.IO.Path]::GetFileName($TargetFile)
    $ext      = [System.IO.Path]::GetExtension($TargetFile).ToLower()

    # ■ ガード処理 1: 拡張子ホワイトリスト
    if ($validExts -notcontains $ext) {
        Write-Warning "スキップ [対象外拡張子]: $fileName"
        return
    }

    # ■ ガード処理 2: 除外パターン (ブラックリスト)
    foreach ($ptn in $ExcludePattern) {
        if ($fileName -like $ptn) {
            Write-Warning "スキップ [除外パターン]: $fileName (一致: $ptn)"
            return
        }
    }

    # 出力先設定
    $parentDir = [System.IO.Path]::GetDirectoryName($TargetFile)
    $outputDir = Join-Path $parentDir "output"
    $outputFile = Join-Path $outputDir $fileName

    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # 読み書き実行
    $sr = $null
    $sw = $null
    try {
        Write-Host "処理中: $fileName ..." -NoNewline
        
        $sr = New-Object System.IO.StreamReader($TargetFile, $encObj)
        $sw = New-Object System.IO.StreamWriter($outputFile, $false, $encObj)
        $sw.NewLine = "`n" # LF固定

        while ($true) {
            $line = $sr.ReadLine()
            if ($null -eq $line) { break }
            
            $u = $line.ToUpper()
            $matched = $false
            foreach ($word in $DeleteList) {
                if ([string]::IsNullOrWhiteSpace($word)) { continue }
                if ($u -like "*$word*") { $matched = $true; break }
            }
            if (-not $matched) { $sw.WriteLine($line) }
        }
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " 失敗 ($($_))" -ForegroundColor Red
    }
    finally {
        if ($sw) { $sw.Dispose() }
        if ($sr) { $sr.Dispose() }
    }
}

# -------------------------------------------------------------
# 4. メインループ
# -------------------------------------------------------------
foreach ($pathStr in $InputPaths) {
    if (-not (Test-Path $pathStr)) { continue }
    
    $item = Get-Item $pathStr
    
    if ($item.PSIsContainer) {
        # フォルダの場合: 対象拡張子にマッチするファイルのみ抽出して渡す
        # ※除外パターンのチェックは Process-SingleFile 内で行う
        $files = Get-ChildItem -Path $item.FullName -File | 
                 Where-Object { $validExts -contains $_.Extension.ToLower() }
        
        foreach ($f in $files) {
            Process-SingleFile -TargetFile $f.FullName
        }
    } else {
        # ファイルの場合
        Process-SingleFile -TargetFile $item.FullName
    }
}