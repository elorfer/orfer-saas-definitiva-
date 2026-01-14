$file = 'c:\appdefinitiva\apps\frontend\lib\core\services\auth_service.dart'
$lines = Get-Content $file
$lines[621] = "      AppLogger.error('[AuthService] ❌ Error guardando datos de autenticación', e, stackTrace);"
$newLines = @()
$newLines += $lines[0..621]
$newLines += "      rethrow;"
$newLines += $lines[622..($lines.Length-1)]
Set-Content $file -Value $newLines
Write-Host "✅ Archivo reparado"
