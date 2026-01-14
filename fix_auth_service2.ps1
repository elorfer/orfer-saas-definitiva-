$file = 'c:\appdefinitiva\apps\frontend\lib\core\services\auth_service.dart'
$lines = Get-Content $file
$newLines = @()
$newLines += $lines[0..622]
$newLines += "    }"
$newLines += "  }"
$newLines += ""
$newLines += $lines[624..($lines.Length-1)]
Set-Content $file -Value $newLines
Write-Host "✅ Archivo reparado - agregado cierre de bloque"
