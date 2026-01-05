<#
.SYNOPSIS
    指定された削除リストに基づき、ファイル内の行をフィルタリングする。

.DESCRIPTION
    InputFile を読み込み、DeleteList に含まれる文字列を含む行を除外して OutputFile に書き出す。
    
    【エンコーディングについて】
    デフォルトは「BOMなしUTF-8 (UTF-8N)」です。
    Shift_JISやBOM付きが必要な場合は、-Encoding パラメータで指定可能です。

.PARAMETER InputFile
    入力ファイルパス (必須)
.PARAMETER OutputFile
    出力ファイルパス (必須)
.PARAMETER DeleteList
    削除対象のキーワードリスト (配列)
.PARAMETER Encoding
    エンコーディング指定用オブジェクト。
    省略時は BOMなしUTF-8 (New-Object System.Text.UTF8Encoding($false)) が使用される。
#>
function Filter-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputFile,

        [Parameter(Mandatory=$true)]
        [string]$OutputFile,

        [string[]]$DeleteList,

        # エンコーディング指定 (任意)
        [System.Text.Encoding]$Encoding = $null
    )

    # -------------------------------------------------------------
    # 1. 事前チェック (入力ファイル確認・出力先作成)
    # -------------------------------------------------------------
    if (-not (Test-Path -Path $InputFile -PathType Leaf)) {
        Write-Error "【失敗】入力ファイルが見つかりません: '$InputFile'"
        return
    }

    $outputDir = Split-Path $OutputFile -Parent
    if (-not [string]::IsNullOrEmpty($outputDir)) {
        if (-not (Test-Path $outputDir)) {
            try {
                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            } catch {
                Write-Error "【失敗】出力先ディレクトリを作成できません: '$outputDir'"
                return
            }
        }
    }

    # -------------------------------------------------------------
    # 2. エンコーディングの決定
    # -------------------------------------------------------------
    if ($null -eq $Encoding) {
        # デフォルト: BOMなしUTF-8
        $Encoding = New-Object System.Text.UTF8Encoding($false)
        $encName = "UTF-8N (Default)"
    } else {
        $encName = $Encoding.EncodingName
    }

    # -------------------------------------------------------------
    # 3. 処理開始
    # -------------------------------------------------------------
    $sr = $null
    $sw = $null

    try {
        Write-Host "処理開始: $InputFile ($encName) ..." -NoNewline

        # Reader/Writer 作成
        $sr = New-Object System.IO.StreamReader($InputFile, $Encoding)
        $sw = New-Object System.IO.StreamWriter($OutputFile, $false, $Encoding)
        $sw.NewLine = "`n" # LF改行固定

        while ($true) {
            $line = $sr.ReadLine()
            if ($null -eq $line) { break }

            $u = $line.ToUpper()
            $matched = $false
            foreach ($pattern in $DeleteList){
                # 削除リストの空文字は判定に使わない (-link "*"回避)
                if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
                
                # 部分一致判定
                if ($u -like "*$pattern*") { 
                    $matched = $true
                    break 
                }
            }

            if (-not $matched) {
                $sw.WriteLine($line)
            }
        }
        
        Write-Host " [完了] -> $OutputFile" -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Error "【エラー】処理中に例外が発生しました: $_"
    }
    finally {
        if ($null -ne $sw) { $sw.Dispose() }
        if ($null -ne $sr) { $sr.Dispose() }
    }
}

# ===============================================
# Entry Point (実行部分・設定例)
# ===============================================

$ScriptBase = $PSScriptRoot

# 削除リストの読み込み
$deleteListPath = Join-Path $ScriptBase "delete_servers.txt"
if (Test-Path $deleteListPath) {
    $deleteList = Get-Content $deleteListPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim().ToUpper() }
} else {
    Write-Warning "削除リストが見つかりません。リスト空で続行します。"
    $deleteList = @()
}

# ------------------------------------------------
# パターンA: デフォルト (BOMなしUTF-8)
# ※ CONFファイルなどは通常これでOK
# ------------------------------------------------
$confIn  = Join-Path $ScriptBase "WAS_COMMON_SERVER.conf"
$confOut = Join-Path $ScriptBase "output/WAS_COMMON_SERVER.conf"

Filter-File -InputFile $confIn -OutputFile $confOut -DeleteList $deleteList


# ------------------------------------------------
# パターンB: Shift_JIS (CP932) を指定する場合
# ※ レガシーなCSVツールやExcelで開く場合に使用
# ------------------------------------------------
$csvIn  = Join-Path $ScriptBase "BATCH_SERVER_LIST.csv"
$csvOut = Join-Path $ScriptBase "output/BATCH_SERVER_LIST.csv"

# Shift_JISオブジェクトを作成
$sjis = [System.Text.Encoding]::GetEncoding(932)

Filter-File -InputFile $csvIn -OutputFile $csvOut -DeleteList $deleteList -Encoding $sjis


# ------------------------------------------------
# パターンC: BOM付きUTF-8 を指定する場合
# ※ 一部のWindowsツールでBOM必須の場合に使用
# ------------------------------------------------
# $bomUtf8 = [System.Text.Encoding]::UTF8
# Filter-File -InputFile "Input.txt" -OutputFile "Output_BOM.txt" -DeleteList $deleteList -Encoding $bomUtf8