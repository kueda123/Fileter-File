param(
    [string]$FilePath
)

if (Test-Path $FilePath) {
    $list = Get-Content $FilePath -Encoding UTF8 | 
        Where-Object { $_.Trim() -ne '' } | 
        ForEach-Object { $_.Trim().ToUpper() }
    
    if ($list) {
        ($list | ForEach-Object { '"' + $_ + '"' }) -join ','
    }
}
