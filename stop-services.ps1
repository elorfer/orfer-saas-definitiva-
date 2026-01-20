# ========================================
# 🛑 DOCKER - DETENER SERVICIOS
# ========================================

Write-Host "🛑 Deteniendo servicios de desarrollo..." -ForegroundColor Yellow
docker-compose -f docker-compose.dev.yml down

Write-Host ""
Write-Host "✅ Servicios detenidos correctamente" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Para iniciar nuevamente: .\start-services.ps1" -ForegroundColor Cyan
