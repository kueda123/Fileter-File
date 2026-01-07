# テストファイル作成スクリプト

# 1. CRLF改行 + BOMありのCSVファイル（先頭行にSERVER1を含む）
$content1 = "hostname,ip,status`r`nSERVER1.example.com,192.168.1.10,active`r`nserver2.example.com,192.168.1.20,active`r`nweb-server.example.com,192.168.1.40,active`r`n"
$enc = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText("test_input_crlf_bom.csv", $content1, $enc)
Write-Host "Created: test_input_crlf_bom.csv (CRLF + BOM)"

# 2. CRLF改行 + BOMありのCONFファイル
$content2 = "# Configuration file`r`nSERVER1.example.com:8080`r`nserver2.example.com:8080`r`nweb-server.example.com:8080`r`n"
[System.IO.File]::WriteAllText("test_input_crlf_bom.conf", $content2, $enc)
Write-Host "Created: test_input_crlf_bom.conf (CRLF + BOM)"

# 3. 先頭レコード（ヘッダー）にSERVER1を含むCSVファイル（CRLF + BOM）
$content3 = "SERVER1,ip,status`r`nserver1.example.com,192.168.1.10,active`r`nserver2.example.com,192.168.1.20,active`r`nweb-server.example.com,192.168.1.40,active`r`n"
[System.IO.File]::WriteAllText("test_input_header_server1.csv", $content3, $enc)
Write-Host "Created: test_input_header_server1.csv (Header contains SERVER1, CRLF + BOM)"

# 4. 期待される出力ファイル（LF改行 + BOMなし）
$expected1 = "hostname,ip,status`nweb-server.example.com,192.168.1.40,active`n"
$encNoBOM = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("test_expected_crlf_bom.csv", $expected1, $encNoBOM)
Write-Host "Created: test_expected_crlf_bom.csv (Expected output)"

$expected2 = "# Configuration file`nweb-server.example.com:8080`n"
[System.IO.File]::WriteAllText("test_expected_crlf_bom.conf", $expected2, $encNoBOM)
Write-Host "Created: test_expected_crlf_bom.conf (Expected output)"

$expected3 = "ip,status`nserver2.example.com,192.168.1.20,active`nweb-server.example.com,192.168.1.40,active`n"
[System.IO.File]::WriteAllText("test_expected_header_server1.csv", $expected3, $encNoBOM)
Write-Host "Created: test_expected_header_server1.csv (Expected output - header removed)"

Write-Host "`nAll test files created successfully!"
