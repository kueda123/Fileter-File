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
    削除リスト（除外対象サーバ名の配列）。BATファイルから指定されます。
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
$script:validExts = $TargetExtensions | ForEach-Object { $_.Trim().ToLower() }
$script:ExcludePattern = $ExcludePattern
$script:encObj = $encObj

Write-Host "=================================================="
Write-Host " エンコーディング : $encNameDisplay"
Write-Host " 対象拡張子       : $($script:validExts -join ', ')"
if ($script:ExcludePattern.Count -gt 0) {
    Write-Host " 除外パターン     : $($script:ExcludePattern -join ', ')"
}
Write-Host "=================================================="

# -------------------------------------------------------------
# 2. 共通設定（削除リスト正規化）
# -------------------------------------------------------------
# BATファイルから渡されたリストを正規化（大文字化）
# 文字列として渡された場合は配列に変換
if ($null -ne $DeleteList) {
    # 配列の場合、要素が1つでカンマを含む場合は文字列として扱う
    if ($DeleteList -is [array] -and $DeleteList.Count -eq 1 -and $DeleteList[0] -is [string] -and $DeleteList[0].Contains(',')) {
        $DeleteList = $DeleteList[0]
    }
    # 文字列の場合はカンマで分割
    if ($DeleteList -is [string]) {
        # カンマ区切りの文字列を配列に変換（引用符を除去）
        # "SERVER1","SERVER2" または SERVER1,SERVER2 のような形式を処理
        $DeleteList = $DeleteList -split ',' | ForEach-Object { 
            $_.Trim().Trim('"').Trim() 
        } | Where-Object { $_ -ne '' }
    }
    # 配列の各要素を処理
    $script:DeleteList = @()
    if ($null -ne $DeleteList) {
        foreach ($item in $DeleteList) {
            if ($null -ne $item) {
                $trimmed = $item.ToString().Trim().ToUpper()
                if ($trimmed -ne '') {
                    $script:DeleteList += $trimmed
                }
            }
        }
    }
    if ($script:DeleteList.Count -gt 0) {
        Write-Host " 除外リスト       : $($script:DeleteList -join ', ')" -ForegroundColor Cyan
    } else {
        $script:DeleteList = @()
    }
} else {
    $script:DeleteList = @()
}

# -------------------------------------------------------------
# 3. 内部関数: 単一ファイルの処理
# -------------------------------------------------------------
function Process-SingleFile {
    param($TargetFile)

    $fileName = [System.IO.Path]::GetFileName($TargetFile)
    $ext      = [System.IO.Path]::GetExtension($TargetFile).ToLower()

    # ■ ガード処理 1: 拡張子ホワイトリスト
    if ($script:validExts -notcontains $ext) {
        Write-Warning "スキップ [対象外拡張子]: $fileName"
        return
    }

    # ■ ガード処理 2: 除外パターン (ブラックリスト)
    foreach ($ptn in $script:ExcludePattern) {
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
        
        $sr = New-Object System.IO.StreamReader($TargetFile, $script:encObj)
        $sw = New-Object System.IO.StreamWriter($outputFile, $false, $script:encObj)
        $sw.NewLine = "`n" # LF固定

        $lineCount = 0
        $excludedCount = 0
        Write-Host " [DeleteList Count: $($script:DeleteList.Count), Type: $($script:DeleteList.GetType().Name), Content: $($script:DeleteList -join '|')]" -ForegroundColor Magenta -NoNewline
        while ($true) {
            $line = $sr.ReadLine()
            if ($null -eq $line) { break }
            
            $lineCount++
            $u = $line.ToUpper()
            $matched = $false
            if ($null -ne $script:DeleteList -and $script:DeleteList.Count -gt 0) {
                foreach ($word in $script:DeleteList) {
                    if ([string]::IsNullOrWhiteSpace($word)) { continue }
                    $pattern = "*$word*"
                    if ($u -like $pattern) { 
                        $matched = $true
                        $excludedCount++
                        break 
                    }
                }
            }
            if (-not $matched) { 
                $sw.WriteLine($line) 
            }
        }
        if ($excludedCount -gt 0) {
            Write-Host " ($excludedCount 行を除外)" -ForegroundColor Yellow -NoNewline
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
                 Where-Object { $script:validExts -contains $_.Extension.ToLower() }
        
        foreach ($f in $files) {
            Process-SingleFile -TargetFile $f.FullName
        }
    } else {
        # ファイルの場合
        Process-SingleFile -TargetFile $item.FullName
    }
}