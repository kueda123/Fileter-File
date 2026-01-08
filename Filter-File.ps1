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

# ---------------------------------------------------------
# 関数定義
# ---------------------------------------------------------

function Initialize-Encoding {
    param([string]$EncodingType)
    
    switch ($EncodingType) {
        "UTF8NoBOM" { return New-Object System.Text.UTF8Encoding($false) }
        "UTF8BOM"   { return New-Object System.Text.UTF8Encoding($true) }
        "ShiftJIS"  { return [System.Text.Encoding]::GetEncoding(932) }
        Default     { throw "Unknown EncodingType: $EncodingType" }
    }
}

function Get-LineEndingCharacter {
    param([string]$LineEnding)
    
    switch ($LineEnding) {
        "CRLF" { return "`r`n" }
        "LF"   { return "`n" }
        Default { throw "Unknown LineEnding: $LineEnding" }
    }
}

function Read-DeleteList {
    param([string]$DeleteListPath)
    
    if (-not (Test-Path $DeleteListPath)) {
        throw "Delete list not found: $DeleteListPath"
    }
    
    $keywords = Get-Content $DeleteListPath -Encoding Default | 
                Where-Object { $_ -match "\S" -and $_ -notmatch "^#" } | 
                ForEach-Object { $_.Trim() }
    
    return $keywords
}

function Build-RegexPattern {
    param([array]$Keywords)
    
    if ($Keywords.Count -eq 0) {
        return $null
    }
    
    $escapedKeywords = $Keywords | ForEach-Object { [Regex]::Escape($_) }
    return $escapedKeywords -join "|"
}

function Get-TargetFiles {
    param(
        [string[]]$InputPaths,
        [string[]]$ValidExtensions,
        [string[]]$ExcludePatterns
    )
    
    $targetFiles = [System.Collections.ArrayList]::new()
    
    foreach ($path in $InputPaths) {
        $cleanPath = $path.Trim('"')
        
        if (Test-Path $cleanPath -PathType Container) {
            $files = Get-ChildItem -Path $cleanPath -Recurse -File | 
                     Where-Object { $ValidExtensions -contains $_.Extension }
            [void]$targetFiles.AddRange($files)
        }
        elseif (Test-Path $cleanPath -PathType Leaf) {
            [void]$targetFiles.Add((Get-Item $cleanPath))
        }
    }
    
    # 除外パターンの適用
    if ($ExcludePatterns.Count -gt 0) {
        $targetFiles = $targetFiles | Where-Object {
            $file = $_
            $shouldExclude = $false
            foreach ($pattern in $ExcludePatterns) {
                if ($file.Name -like $pattern) {
                    $shouldExclude = $true
                    break
                }
            }
            -not $shouldExclude
        }
    }
    
    return $targetFiles
}

function Process-File {
    param(
        [System.IO.FileInfo]$File,
        [string]$RegexPattern,
        [System.Text.Encoding]$Encoding,
        [string]$LineEnding
    )
    
    $outputDir = Join-Path $File.DirectoryName "output"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $outputPath = Join-Path $outputDir $File.Name
    
    # 同名ファイルチェック
    if (Test-Path $outputPath) {
        Write-Output "[WARNING] Output file already exists. Skipped: $($File.Name)"
        return $false, $true  # (success, hasWarning)
    }
    
    try {
        # ファイル読み込み
        $content = Get-Content $File.FullName
        if ($null -eq $content) {
            $content = @()
        }
        
        # フィルタリング
        $filteredContent = if ($null -ne $RegexPattern) {
            $content | Where-Object { $_ -notmatch $RegexPattern }
        } else {
            $content
        }
        
        # 書き込みテキスト生成
        $textToWrite = if ($filteredContent.Count -gt 0) {
            ($filteredContent -join $LineEnding) + $LineEnding
        } else {
            ""
        }
        
        # 保存
        [System.IO.File]::WriteAllText($outputPath, $textToWrite, $Encoding)
        Write-Output "  -> Exported to: output\$($File.Name)"
        
        return $true, $false  # (success, hasWarning)
    }
    catch {
        Write-Error "Failed to process file: $($File.Name) - $($_.Exception.Message)"
        return $false, $false  # (success, hasWarning)
    }
}

# ---------------------------------------------------------
# メイン処理
# ---------------------------------------------------------

# コンソール出力をUTF-8(BOM付)に強制し、BAT側のパイプ/リダイレクトでの文字化けを防ぐ
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($true)

Write-Output "[INFO] Starting Filter-File.ps1"
Write-Output "[INFO] Encoding Setting: $EncodingType"
Write-Output "[INFO] LineEnding Setting: $LineEnding"

try {
    # エンコーディングと改行コードの初期化
    $encObj = Initialize-Encoding -EncodingType $EncodingType
    $newLineChar = Get-LineEndingCharacter -LineEnding $LineEnding
    
    # 削除リストの読み込み
    $deleteKeywords = Read-DeleteList -DeleteListPath $DeleteListPath
    
    if ($deleteKeywords.Count -eq 0) {
        Write-Output "[WARNING] Delete list is empty. No lines will be deleted."
        $hasWarning = $true
        $regexPattern = $null
    } else {
        $regexPattern = Build-RegexPattern -Keywords $deleteKeywords
        Write-Output "[INFO] Loaded $($deleteKeywords.Count) delete keywords (Compiled to Regex)."
    }
    
    # 対象ファイルの特定
    $rawPaths = $InputPaths -split ","
    $validExts = ($TargetExtensions -split ",").Trim()
    $excludePats = if ($ExcludePattern) {
        ($ExcludePattern -split ",").Trim() | Where-Object { $_ }
    } else {
        @()
    }
    
    $targetFiles = Get-TargetFiles -InputPaths $rawPaths -ValidExtensions $validExts -ExcludePatterns $excludePats
    
    if ($targetFiles.Count -eq 0) {
        Write-Output "[WARNING] No target files found to process."
        exit $EXIT_WARNING
    }
    
    Write-Output "[INFO] Target Files Count: $($targetFiles.Count)"
    
    # ファイル処理実行
    $hasWarning = $false
    foreach ($file in $targetFiles) {
        Write-Output "Processing: $($file.FullName)"
        
        $success, $fileWarning = Process-File -File $file -RegexPattern $regexPattern -Encoding $encObj -LineEnding $newLineChar
        
        if ($fileWarning) {
            $hasWarning = $true
        }
    }
    
    # 終了処理
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
