param(
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    Write-Host "File not found: $FilePath"
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($FilePath)
Write-Host "File: $FilePath"
Write-Host "File size: $($bytes.Length) bytes"

# BOMチェック
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "BOM: UTF-8 with BOM (EF BB BF)"
} else {
    Write-Host "BOM: UTF-8 without BOM (No BOM)"
}

# 改行コードチェック
$crlfCount = 0
$lfCount = 0
$crCount = 0

for ($i = 0; $i -lt ($bytes.Length - 1); $i++) {
    if ($bytes[$i] -eq 0x0D -and $bytes[$i+1] -eq 0x0A) {
        $crlfCount++
    } elseif ($bytes[$i] -eq 0x0A -and ($i -eq 0 -or $bytes[$i-1] -ne 0x0D)) {
        $lfCount++
    } elseif ($bytes[$i] -eq 0x0D -and ($i -eq ($bytes.Length - 1) -or $bytes[$i+1] -ne 0x0A)) {
        $crCount++
    }
}

# 最後のバイトがLFの場合
if ($bytes.Length -gt 0 -and $bytes[$bytes.Length - 1] -eq 0x0A -and ($bytes.Length -eq 1 -or $bytes[$bytes.Length - 2] -ne 0x0D)) {
    $lfCount++
} elseif ($bytes.Length -gt 0 -and $bytes[$bytes.Length - 1] -eq 0x0D) {
    $crCount++
}

Write-Host "Line endings:"
Write-Host "  CRLF (0x0D 0x0A): $crlfCount"
Write-Host "  LF (0x0A): $lfCount"
Write-Host "  CR (0x0D): $crCount"

if ($crlfCount -gt 0 -and $lfCount -eq 0 -and $crCount -eq 0) {
    Write-Host "Result: CRLF (Windows style)"
} elseif ($lfCount -gt 0 -and $crlfCount -eq 0 -and $crCount -eq 0) {
    Write-Host "Result: LF (Unix style)"
} elseif ($crCount -gt 0) {
    Write-Host "Result: CR (Mac style) or mixed"
} else {
    Write-Host "Result: Mixed or no line endings"
}
