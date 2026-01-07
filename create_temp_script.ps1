param(
    [string]$TempDeleteList,
    [string]$PsScript,
    [string]$Encoding,
    [string]$TargetExts,
    [string]$ExcludePattern,
    [string]$InputPaths,
    [string]$OutputScript
)

$lines = @()
$lines += "`$deleteListContent = Get-Content '$TempDeleteList' -Raw"
$lines += "`$inputPathsArray = '$InputPaths' -split ',' | ForEach-Object { `$_.Trim() }"

# TargetExtsとExcludePatternを配列に変換
$targetExtsArray = $TargetExts -split ',' | ForEach-Object { $_.Trim().Trim('"') } | ForEach-Object { "'$_'" }
$excludePatternArray = $ExcludePattern -split ',' | ForEach-Object { $_.Trim().Trim('"') } | ForEach-Object { "'$_'" }

$lines += "`$targetExts = @($($targetExtsArray -join ', '))"
$lines += "`$excludePattern = @($($excludePatternArray -join ', '))"
$lines += "& '$PsScript' -EncodingType '$Encoding' -TargetExtensions `$targetExts -ExcludePattern `$excludePattern -DeleteList `$deleteListContent -InputPaths `$inputPathsArray"

$content = $lines -join "`r`n"
$content | Out-File -FilePath $OutputScript -Encoding UTF8 -NoNewline
