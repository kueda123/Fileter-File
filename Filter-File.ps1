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
    [string]$EncodingType = "UTF8NoBOM",

    [string[]]$TargetExtensions = @(".csv", ".conf", ".xml"),

    [string[]]$ExcludePattern = @(),

    [string[]]$DeleteList,

    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$InputPaths
)

# BATファイルから渡された配列パラメータを正規化
# 文字列として渡された場合は配列に変換
if ($TargetExtensions -is [string]) {
    # カンマ区切りの文字列を配列に変換（引用符を除去）
    $TargetExtensions = $TargetExtensions -split ',' | ForEach-Object { $_.Trim('"', ' ') } | Where-Object { $_ -ne '' }
} elseif ($TargetExtensions -is [array] -and $TargetExtensions.Count -gt 0) {
    # 配列の場合、各要素を処理
    $tempArray = @()
    foreach ($item in $TargetExtensions) {
        if ($item -is [string] -and $item.Contains(',')) {
            # カンマを含む場合は分割
            $splitItems = $item -split ',' | ForEach-Object { $_.Trim('"', ' ') } | Where-Object { $_ -ne '' }
            $tempArray += $splitItems
        } elseif ($item -is [string]) {
            $trimmed = $item.Trim('"', ' ')
            if ($trimmed -ne '') {
                $tempArray += $trimmed
            }
        }
    }
    if ($tempArray.Count -gt 0) {
        $TargetExtensions = $tempArray
    }
}
if ($ExcludePattern -is [string]) {
    # カンマ区切りの文字列を配列に変換（引用符を除去）
    $ExcludePattern = $ExcludePattern -split ',' | ForEach-Object { $_.Trim('"', ' ') } | Where-Object { $_ -ne '' }
} elseif ($ExcludePattern -is [array] -and $ExcludePattern.Count -eq 1 -and $ExcludePattern[0] -is [string] -and $ExcludePattern[0].Contains(',')) {
    # 配列の要素が1つでカンマを含む場合は文字列として扱う
    $ExcludePattern = $ExcludePattern[0] -split ',' | ForEach-Object { $_.Trim('"', ' ') } | Where-Object { $_ -ne '' }
}

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
    # 文字列として扱う値を取得
    $strValue = $null
    if ($DeleteList -is [string]) {
        $strValue = $DeleteList
    } elseif ($DeleteList -is [array] -and $DeleteList.Count -eq 1 -and $null -ne $DeleteList[0] -and $DeleteList[0] -is [string]) {
        $strValue = $DeleteList[0].ToString()
    } elseif ($DeleteList -is [array] -and $DeleteList.Count -gt 0) {
        # 既に配列の場合はそのまま処理
        $script:DeleteList = @()
        foreach ($item in $DeleteList) {
            if ($null -ne $item) {
                $trimmed = $item.ToString().Trim().ToUpper()
                if ($trimmed -ne '') {
                    $script:DeleteList += $trimmed
                }
            }
        }
        if ($script:DeleteList.Count -gt 0) {
            Write-Host " 除外リスト       : $($script:DeleteList -join ', ')" -ForegroundColor Cyan
        } else {
            $script:DeleteList = @()
        }
    }
    
    # 文字列の場合はカンマで分割
    if ($null -ne $strValue) {
        $strValue = $strValue.Trim()
        # カンマ区切りの文字列を配列に変換（引用符を除去）
        # "SERVER1","SERVER2" または SERVER1,SERVER2 のような形式を処理
        $splitResult = $strValue -split ','
        $script:DeleteList = @()
        foreach ($item in $splitResult) {
            $trimmed = $item.Trim().Trim('"').Trim().ToUpper()
            if ($trimmed -ne '') {
                $script:DeleteList += $trimmed
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
        Write-Host "[WARNING] スキップ [対象外拡張子]: $fileName" -ForegroundColor Yellow
        return
    }

    # ■ ガード処理 2: 除外パターン (ブラックリスト)
    foreach ($ptn in $script:ExcludePattern) {
        if ($fileName -like $ptn) {
            Write-Host "[WARNING] スキップ [除外パターン]: $fileName (一致: $ptn)" -ForegroundColor Yellow
            return
        }
    }

    # 出力先設定
    $parentDir = [System.IO.Path]::GetDirectoryName($TargetFile)
    $outputDir = Join-Path $parentDir "output"
    $outputFile = Join-Path $outputDir $fileName

    # 安全チェック: 元ファイルと出力ファイルが同じパスになっていないか確認
    if ($TargetFile -eq $outputFile) {
        Write-Host "[ERROR] 元ファイルと出力ファイルが同じパスです" -ForegroundColor Red
        Write-Host "  元ファイル: $TargetFile" -ForegroundColor Red
        Write-Host "  出力ファイル: $outputFile" -ForegroundColor Red
        return
    }

    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # 既存の出力ファイルが存在する場合の処理
    # 注意: これは出力ファイル（$outputFile）のみをチェックし、元ファイル（$TargetFile）には影響しません
    if (Test-Path $outputFile) {
        Write-Host "[WARNING] スキップ [既存ファイル]: $fileName" -ForegroundColor Yellow
        Write-Host "  警告: 出力ファイルが存在するのでスキップしました。再処理が必要なら、既存ファイルを移動してください。" -ForegroundColor Yellow
        Write-Host "  出力ファイル: $outputFile" -ForegroundColor Yellow
        return
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
        Write-Host "[ERROR] 処理失敗: $fileName ($($_))" -ForegroundColor Red
    }
    finally {
        if ($sw) { $sw.Dispose() }
        if ($sr) { $sr.Dispose() }
    }
}

# -------------------------------------------------------------
# 4. メインループ
# -------------------------------------------------------------
try {
    if ($InputPaths -eq $null) {
        Write-Host "[ERROR] InputPathsがnullです" -ForegroundColor Red
        Write-Host "[ERROR] スクリプトを終了します" -ForegroundColor Red
        exit 1
    }
    if ($InputPaths.Count -eq 0) {
        Write-Host "[ERROR] InputPathsが空です" -ForegroundColor Red
        Write-Host "[ERROR] スクリプトを終了します" -ForegroundColor Red
        exit 1
    }
    Write-Host "[INFO] 処理対象ファイル数: $($InputPaths.Count)" -ForegroundColor Cyan
    foreach ($p in $InputPaths) {
        Write-Host "[INFO]   - $p" -ForegroundColor Cyan
    }
} catch {
    Write-Host "[ERROR] InputPathsの処理中にエラーが発生しました: $_" -ForegroundColor Red
    Write-Host "[ERROR] エラー詳細: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

foreach ($pathStr in $InputPaths) {
    if (-not (Test-Path $pathStr)) { 
        Write-Host "[WARN] パスが存在しません: $pathStr" -ForegroundColor Yellow
        continue 
    }
    
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

# 出力を確実にフラッシュ
[Console]::Out.Flush()
[Console]::Error.Flush()