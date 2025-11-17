# Script para obtener la IP local de tu PC
# Útil para configurar la app cuando uses un dispositivo físico

Write-Host "🔍 Buscando tu IP local..." -ForegroundColor Cyan
Write-Host ""

# Obtener todas las interfaces de red
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -notlike "127.*" -and 
    $_.IPAddress -notlike "169.*" 
}

Write-Host "📱 IPs locales encontradas:" -ForegroundColor Green
Write-Host ""

foreach ($adapter in $adapters) {
    $interface = Get-NetAdapter | Where-Object { $_.ifIndex -eq $adapter.InterfaceIndex }
    Write-Host "  Interface: $($interface.Name)" -ForegroundColor Yellow
    Write-Host "  IP: $($adapter.IPAddress)" -ForegroundColor White
    Write-Host ""
}

Write-Host "📝 Para usar un dispositivo físico:" -ForegroundColor Cyan
Write-Host "   1. Copia una de las IPs de arriba" -ForegroundColor White
Write-Host "   2. Abre: apps/frontend/lib/core/config/app_config.dart" -ForegroundColor White
Write-Host "   3. Cambia 'http://10.0.2.2:3000/api' por 'http://TU_IP:3000/api'" -ForegroundColor White
Write-Host ""
Write-Host "💡 Para emulador Android, usa: http://10.0.2.2:3000/api" -ForegroundColor Green
Write-Host "💡 Para web, usa: http://localhost:3000/api" -ForegroundColor Green
Write-Host ""
