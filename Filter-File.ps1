<#
.SYNOPSIS
    指定されたリストに基づいて行を削除し、指定のエンコード・改行コードで保存するスクリプト
.DESCRIPTION
    BATファイルからの呼び出しを想定。
    - 入力ファイルの読み込み (Get-Content)
    - 除外リストに基づく行削除
    - outputフォルダの作成と出力
    - 指定エンコード (UTF8NoBOM, ShiftJIS, UTF8BOM) での書き込み
    - 指定改行コード (LF, CRLF) での書き込み
#>
param(
    [Parameter(Mandatory=$true)][string]$InputPaths,
    [Parameter(Mandatory=$true)][string]$DeleteListPath,
    [string]$EncodingType = "UTF8NoBOM", # UTF8NoBOM, UTF8BOM, ShiftJIS
    [string]$LineEnding = "LF",          # LF, CRLF
    [string]$TargetExtensions = ".conf,.txt",
    [string]$ExcludePattern = ""
)

$ErrorActionPreference = "Stop"

try {
    # ---------------------------------------------------------
    # 1. 設定の準備
    # ---------------------------------------------------------
    Write-Host "[INFO] Starting Filter-File.ps1"
    Write-Host "[INFO] Encoding Setting: $EncodingType"
    Write-Host "[INFO] LineEnding Setting: $LineEnding"

    # エンコーディングオブジェクトの生成
    $encObj = $null
    switch ($EncodingType) {
        "UTF8NoBOM" { $encObj = New-Object System.Text.UTF8Encoding($false) }
        "UTF8BOM"   { $encObj = New-Object System.Text.UTF8Encoding($true) }
        "ShiftJIS"  { $encObj = [System.Text.Encoding]::GetEncoding(932) }
        Default     { throw "Unknown EncodingType: $EncodingType" }
    }

    # 改行コード文字の生成
    $newLineChar = ""
    if ($LineEnding -eq "CRLF") {
        $newLineChar = "`r`n"
    } elseif ($LineEnding -eq "LF") {
        $newLineChar = "`n"
    } else {
        throw "Unknown LineEnding: $LineEnding"
    }

    # ---------------------------------------------------------
    # 2. 削除リストの読み込み
    # ---------------------------------------------------------
    if (-not (Test-Path $DeleteListPath)) {
        throw "Delete list not found: $DeleteListPath"
    }
    # 空行とコメント(#)を除外してリスト化
    $deleteKeywords = Get-Content $DeleteListPath -Encoding Default | Where-Object { $_ -match "\S" -and $_ -notmatch "^#" }
    Write-Host "[INFO] Loaded $($deleteKeywords.Count) delete keywords."

    # ---------------------------------------------------------
    # 3. 対象ファイルのリストアップ
    # ---------------------------------------------------------
    # BATから渡されるInputPathsはカンマ区切り文字列の可能性があるため分割
    $pathList = $InputPaths -split ","
    
    $targetFiles = @()
    $validExtensions = $TargetExtensions -split "," | ForEach-Object { $_.Trim() }
    $excludePatterns = $ExcludePattern -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    foreach ($p in $pathList) {
        $p = $p.TrimStart('"').TrimEnd('"') # 引用符除去
        if (Test-Path $p -PathType Container) {
            # ディレクトリなら再帰検索
            $files = Get-ChildItem -Path $p -Recurse -File | Where-Object { 
                $validExtensions -contains $_.Extension 
            }
            $targetFiles += $files
        } elseif (Test-Path $p -PathType Leaf) {
            # ファイルなら直接追加
            $targetFiles += (Get-Item $p)
        }
    }

    # 除外パターンの適用
    if ($excludePatterns.Count -gt 0) {
        $targetFiles = $targetFiles | Where-Object {
            $f = $_
            $isExcluded = $false
            foreach ($pat in $excludePatterns) {
                if ($f.Name -like $pat) { $isExcluded = $true; break }
            }
            -not $isExcluded
        }
    }

    if ($targetFiles.Count -eq 0) {
        Write-Host "[WARNING] No target files found to process."
        exit 0
    }

    Write-Host "[INFO] Target Files Count: $($targetFiles.Count)"

    # ---------------------------------------------------------
    # 4. ファイル処理実行
    # ---------------------------------------------------------
    foreach ($file in $targetFiles) {
        Write-Host "Processing: $($file.FullName)"
        
        # 読み込み (Get-ContentはBOM等からエンコードを自動判別する)
        $content = Get-Content $file.FullName
        if ($content -eq $null) { $content = @() } # 空ファイル対応

        # フィルタリング (キーワードが含まれる行を除外)
        # 行ごとにチェックを行う
        $filteredContent = @()
        foreach ($line in $content) {
            $shouldDelete = $false
            foreach ($kw in $deleteKeywords) {
                if ($line -like "*$kw*") {
                    $shouldDelete = $true
                    # Write-Host "  [DEL] $line" # デバッグ用
                    break
                }
            }
            if (-not $shouldDelete) {
                $filteredContent += $line
            }
        }

        # 結合して書き込み用文字列を作成
        if ($filteredContent.Count -gt 0) {
            $textToWrite = $filteredContent -join $newLineChar
            # 最終行にも改行を入れる
            $textToWrite += $newLineChar
        } else {
            $textToWrite = ""
        }

        # -----------------------------------------------------
        # 出力先ディレクトリの構築 (カレント/output)
        # -----------------------------------------------------
        $outputDir = Join-Path $file.DirectoryName "output"
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # 出力ファイルパスの構築
        $outputPath = Join-Path $outputDir $file.Name

        # 安全策：同名ファイルが存在する場合はスキップ (README仕様)
        if (Test-Path $outputPath) {
            # バッチ側で検知できるよう [WARNING] タグ付きの Write-Host に変更
            Write-Host "[WARNING] Output file already exists. Skipped: $($file.Name)"
            continue
        }

        # 書き込み (System.IO.Fileを使用)
        try {
            [System.IO.File]::WriteAllText($outputPath, $textToWrite, $encObj)
            Write-Host "  -> Exported to: output\$($file.Name)"
        } catch {
            Write-Error "Failed to write file: $outputPath - $($_.Exception.Message)"
            continue
        }
    }

    Write-Host "[INFO] Completed successfully."
    exit 0

} catch {
    Write-Error "Fatal Error: $($_.Exception.Message)"
    exit 1
}