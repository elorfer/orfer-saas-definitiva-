$keystore = "$HOME\.android\debug.keystore"
$password = "android"
$alias = "androiddebugkey"
$outputFile = "local_sha1.txt"

$v = & keytool -list -v -keystore $keystore -alias $alias -storepass $password
$sha1Line = $v | Select-String "SHA1:"
if ($sha1Line) {
    $sha1 = $sha1Line.ToString().Trim().Replace("SHA1: ", "")
    $sha1 | Out-File -FilePath $outputFile -Encoding ascii
    Write-Output "SHA1_LOCAL: $sha1"
} else {
    Write-Error "No se encontró la línea SHA1"
}
