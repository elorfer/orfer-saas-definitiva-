$keystore = "$HOME\.android\debug.keystore"
$password = "android"
$alias = "androiddebugkey"
$tempFile = "temp_cert.bin"
$outputFile = "fb_hash.txt"

if (Test-Path $tempFile) { Remove-Item $tempFile }
if (Test-Path $outputFile) { Remove-Item $outputFile }

# Exportar el certificado
& keytool -exportcert -alias $alias -keystore $keystore -storepass $password -file $tempFile

if (Test-Path $tempFile) {
    $certBytes = [System.IO.File]::ReadAllBytes($tempFile)
    $sha1 = [System.Security.Cryptography.HashAlgorithm]::Create("SHA1")
    $hash = $sha1.ComputeHash($certBytes)
    $base64 = [System.Convert]::ToBase64String($hash)
    $base64 | Out-File -FilePath $outputFile -Encoding ascii
    Remove-Item $tempFile
}
