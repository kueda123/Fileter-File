<#
.SYNOPSIS
    削除リストに含まれるホスト名を含む行をフィルターする

.DESCRIPTION
    スクリプトと同じフォルダにある fileInのフィルター結果をfileOutに出力する
    
.NOTES
    対象ファイルは、CSV形式やCONF形式で、
#>
function Filter-File {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [string[]]$DeleteList
    )
    # Shift_JIS(932)エンコーディングを明示
    $enc = [System.Text.Encoding]::UTF8

    # 出力ファイルを初期化
    Remove-Item $OutputFile -ErrorAction SilentlyContinue

    # Reader/Writerをenc付きで作成
    $sr = New-Object System.IO.StreamReader($InputFile, $enc)
    $sv = New-Object System.IO.StreamWriter($OutputFile, $false, $enc)
    try {
        $sv.NewLine = "`n" # LF改行固定

        while($true) {
            $line = $sr.ReadLine()
            if ($null -eq $line) { break }

            $u = $line.ToUpper()

            $matched = $false
            foreach ($pattern in $DeleteList){
                # 削除リストの空文字は判定に使わない (-link "*"回避)
                if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
                if ($u -like "*$pattern*"){$matched = $true; break }
            }
            if (-not $matched){
                $sv.WriteLine($line)
            }
        }
    }
    finally {
        $sv.Dispose()
    }
}

# ===============================================
# Entry Point
# ===============================================

# このスクリプトの配置ディレクトリ
$ScriptBase = $PSScriptRoot

# 削除リストの読み込み(大文字化を含む)
$deleteList = Get-Content (Join-Path $ScriptBase "delete_servers.txt") |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.Trim().ToUpper() }

# 一つ目のファイル I
$fileIn = Join-Path $ScriptBase "WAS_COMMON_SERVER.conf"
$fileOut = Join-Path $ScriptBase "output/WAS_COMMON_SERVER.conf"
Filter-File -InputFile $fileIn -OutputFile $fileOut -DeleteList $deleteList
Write-Output "処理完了: $fileOut を生成しました。"

# 二つ目のファイル I
$fileIn = Join-Path $ScriptBase "BATCH_SERVER_LIST.csv"
$fileOut = Join-Path $ScriptBase "output/BATCH_SERVER_LIST.csv"
Filter-File -InputFile $fileIn -OutputFile $fileOut -DeleteList $deleteList
Write-Output "処理完了: $fileOut を生成しました。"