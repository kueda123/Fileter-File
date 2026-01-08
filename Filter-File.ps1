<#
.SYNOPSIS
    指定された削除リストに基づいて行を除外し、指定のエンコード・改行コードで保存するスクリプト
.DESCRIPTION
    BATファイルからの呼び出しを想定。
    - 正規表現による高速フィルタリング
    - outputフォルダへの自動出力
    - 終了コードによるBAT側へのステータス通知 (0:成功, 1:エラー, 2:警告)
#>
param(
    [Parameter(Mandatory=$true)][string]$InputPaths,
    [Parameter(Mandatory=$true)][string]$DeleteListPath,
    [string]$EncodingType = "UTF8NoBOM", 
    [string]$LineEnding = "LF",          
    [string]$TargetExtensions = ".conf,.txt",
    [string]$ExcludePattern = ""
)

$ErrorActionPreference = "Stop"

# 定数定義 (終了コード)
Set-Variable -Name EXIT_SUCCESS -Value 0 -Option Constant
Set-Variable -Name EXIT_ERROR   -Value 1 -Option Constant
Set-Variable -Name EXIT_WARNING -Value 2 -Option Constant

# 状態フラグ
$hasWarning = $false

# ---------------------------------------------------------
# 1. 初期設定 (Console Output & Encoding)
# ---------------------------------------------------------
# コンソール出力をUTF-8(BOM付)に強制し、BAT側のパイプ/リダイレクトでの文字化けを防ぐ
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($true)

Write-Output "[INFO] Starting Filter-File.ps1"
Write-Output "[INFO] Encoding Setting: $EncodingType"
Write-Output "[INFO] LineEnding Setting: $LineEnding"

# エンコーディングオブジェクト生成
$encObj = switch ($EncodingType) {
    "UTF8NoBOM" { New-Object System.Text.UTF8Encoding($false) }
    "UTF8BOM"   { New-Object System.Text.UTF8Encoding($true) }
    "ShiftJIS"  { [System.Text.Encoding]::GetEncoding(932) }
    Default     { throw "Unknown EncodingType: $EncodingType" }
}

# 改行コード生成
$newLineChar = switch ($LineEnding) {
    "CRLF" { "`r`n" }
    "LF"   { "`n" }
    Default { throw "Unknown LineEnding: $LineEnding" }
}

try {
    # ---------------------------------------------------------
    # 2. 削除リスト読み込み (Regexコンパイル)
    # ---------------------------------------------------------
    if (-not (Test-Path $DeleteListPath)) {
        throw "Delete list not found: $DeleteListPath"
    }

    $deleteKeywords = Get-Content $DeleteListPath -Encoding Default | 
                      Where-Object { $_ -match "\S" -and $_ -notmatch "^#" } | 
                      ForEach-Object { $_.Trim() }

    if ($deleteKeywords.Count -eq 0) {
        Write-Output "[WARNING] Delete list is empty. No lines will be deleted."
        $hasWarning = $true
        $regexPattern = $null
    } else {
        # キーワードをエスケープしてOR条件で結合 (高速化)
        $escapedKeywords = $deleteKeywords | ForEach-Object { [Regex]::Escape($_) }
        $regexPattern = $escapedKeywords -join "|"
        Write-Output "[INFO] Loaded $($deleteKeywords.Count) delete keywords (Compiled to Regex)."
    }

    # ---------------------------------------------------------
    # 3. 対象ファイル特定
    # ---------------------------------------------------------
    $rawPaths = $InputPaths -split ","
    $validExts = ($TargetExtensions -split ",").Trim()
    $excludePats = ($ExcludePattern -split ",").Trim() | Where-Object { $_ }

    $targetFiles = @()

    foreach ($p in $rawPaths) {
        $cleanPath = $p.Trim('"') 
        if (Test-Path $cleanPath -PathType Container) {
            $files = Get-ChildItem -Path $cleanPath -Recurse -File | 
                     Where-Object { $validExts -contains $_.Extension }
            $targetFiles += $files
        } elseif (Test-Path $cleanPath -PathType Leaf) {
            $targetFiles += Get-Item $cleanPath
        }
    }

    # 除外パターンの適用
    if ($excludePats.Count -gt 0) {
        $targetFiles = $targetFiles | Where-Object {
            $f = $_
            $shouldExclude = $false
            foreach ($pat in $excludePats) {
                if ($f.Name -like $pat) { $shouldExclude = $true; break }
            }
            -not $shouldExclude
        }
    }

    if ($targetFiles.Count -eq 0) {
        Write-Output "[WARNING] No target files found to process."
        exit $EXIT_WARNING
    }

    Write-Output "[INFO] Target Files Count: $($targetFiles.Count)"

    # ---------------------------------------------------------
    # 4. ファイル処理実行
    # ---------------------------------------------------------
    foreach ($file in $targetFiles) {
        Write-Output "Processing: $($file.FullName)"

        # 出力先フォルダ作成
        $outputDir = Join-Path $file.DirectoryName "output"
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        $outputPath = Join-Path $outputDir $file.Name

        # 同名ファイルチェック (スキップ)
        if (Test-Path $outputPath) {
            Write-Output "[WARNING] Output file already exists. Skipped: $($file.Name)"
            $hasWarning = $true
            continue
        }

        try {
            # 読み込み
            $content = Get-Content $file.FullName
            if ($null -eq $content) { $content = @() }

            # フィルタリング
            if ($null -ne $regexPattern) {
                $filteredContent = $content | Where-Object { $_ -notmatch $regexPattern }
            } else {
                $filteredContent = $content
            }

            # 書き込みテキスト生成
            $textToWrite = ""
            if ($filteredContent.Count -gt 0) {
                $textToWrite = ($filteredContent -join $newLineChar) + $newLineChar
            }

            # 保存
            [System.IO.File]::WriteAllText($outputPath, $textToWrite, $encObj)
            Write-Output "  -> Exported to: output\$($file.Name)"

        } catch {
            Write-Error "Failed to process file: $($file.Name) - $($_.Exception.Message)"
        }
    }

    # ---------------------------------------------------------
    # 5. 終了処理
    # ---------------------------------------------------------
    if ($hasWarning) {
        Write-Output "[INFO] Completed with warnings."
        exit $EXIT_WARNING
    } else {
        Write-Output "[INFO] Completed successfully."
        exit $EXIT_SUCCESS
    }

} catch {
    Write-Error "Fatal Error: $($_.Exception.Message)"
    exit $EXIT_ERROR
}