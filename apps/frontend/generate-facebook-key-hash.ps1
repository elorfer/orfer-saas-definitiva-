# Script para generar el Facebook Key Hash correcto (28 caracteres)
# Basado en el SHA1 del certificado

$keystorePath = "$env:USERPROFILE\.android\debug.keystore"
$alias = "androiddebugkey"
$storepass = "android"

Write-Host "Generando Facebook Key Hash (28 caracteres)..." -ForegroundColor Cyan
Write-Host ""

# Obtener la informacion del certificado
$keytoolOutput = keytool -list -v -keystore $keystorePath -alias $alias -storepass $storepass -keypass $storepass 2>$null

# Buscar la linea del SHA1
$sha1Line = $keytoolOutput | Select-String "SHA1:"

if ($sha1Line) {
    # Extraer el SHA1 (formato: SHA1: XX:XX:XX:...)
    $sha1Hex = $sha1Line.ToString() -replace '.*SHA1:\s*', '' -replace '\s', ''
    
    Write-Host "SHA1 encontrado: $sha1Hex" -ForegroundColor Green
    Write-Host ""
    
    # Convertir el SHA1 hexadecimal a bytes
    $sha1Bytes = New-Object byte[] 20
    for ($i = 0; $i -lt 20; $i++) {
        $sha1Bytes[$i] = [Convert]::ToByte($sha1Hex.Substring($i * 3, 2), 16)
    }
    
    # Convertir a Base64
    $base64 = [Convert]::ToBase64String($sha1Bytes)
    
    Write-Host "========================================" -ForegroundColor White
    Write-Host ""
    Write-Host "TU FACEBOOK KEY HASH (28 caracteres):" -ForegroundColor Green
    Write-Host ""
    Write-Host $base64 -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Longitud: $($base64.Length) caracteres" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "========================================" -ForegroundColor White
    Write-Host ""
    
    # Guardar en archivo
    $base64 | Out-File -FilePath "facebook_key_hash_28.txt" -Encoding utf8 -NoNewline
    
    # Copiar al portapapeles
    Set-Clipboard -Value $base64
    Write-Host "Guardado en: facebook_key_hash_28.txt" -ForegroundColor Green
    Write-Host "Copiado al portapapeles!" -ForegroundColor Green
    Write-Host ""
    
} else {
    Write-Host "Error: No se pudo encontrar el SHA1 del certificado" -ForegroundColor Red
}
