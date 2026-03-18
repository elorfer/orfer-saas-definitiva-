$sha1_signing = "EF:AA:C5:B1:1D:CB:49:0B:2F:65:F1:BD:72:A0:41:24:F0:0C:D5:1B"
$sha1_upload = "89:EA:D8:5B:80:C1:44:BB:DF:A3:60:2D:F0:F5:BB:82:57:EB:58:07"

function Get-Base64Hash($sha1Hex) {
    $bytes = $sha1Hex.Split(':') | ForEach-Object { [System.Convert]::ToByte($_, 16) }
    return [System.Convert]::ToBase64String($bytes)
}

$signingHash = Get-Base64Hash $sha1_signing
$uploadHash = Get-Base64Hash $sha1_upload

"SIGNING_KEY_HASH=$signingHash" | Out-File -FilePath "hashes.txt" -Encoding ascii
"UPLOAD_KEY_HASH=$uploadHash" | Out-File -FilePath "hashes.txt" -Append -Encoding ascii
