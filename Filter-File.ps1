<#
.SYNOPSIS
    指定されたリストに基づいて行を削除し、指定のエンコード・改行コードで保存するスクリプト
.DESCRIPTION
    BATファイルからの呼び出しを想定。
    - 入力ファイルの読み込み (Get-Content)
    - 除外リストに基づく行削除
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
        Write-Warning "No target files found to process."
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
                    # Write-Host "  [DEL] $line" # デバッグ用（大量に出るので通常はコメントアウト）
                    break
                }
            }
            if (-not $shouldDelete) {
                $filteredContent += $line
            }
        }

        # 結合して書き込み用文字列を作成
        # 注意: 配列が空の場合や1行の場合の処理
        if ($filteredContent.Count -gt 0) {
            $textToWrite = $filteredContent -join $newLineChar
            # 最終行にも改行を入れるか？（通常Linux設定ファイル等は末尾改行が望ましい）
            $textToWrite += $newLineChar
        } else {
            $textToWrite = ""
        }

        # 書き込み (System.IO.Fileを使用することでエンコードと改行を厳密に制御)
        try {
            [System.IO.File]::WriteAllText($file.FullName, $textToWrite, $encObj)
        } catch {
            Write-Error "Failed to write file: $($file.FullName) - $($_.Exception.Message)"
            continue
        }
    }

    Write-Host "[INFO] Completed successfully."
    exit 0

} catch {
    Write-Error "Fatal Error: $($_.Exception.Message)"
    exit 1
}