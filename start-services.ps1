# ========================================
# 🐳 DOCKER - SERVICIOS DE DESARROLLO
# ========================================
# Scripts para iniciar/detener PostgreSQL y Redis

# 🚀 Iniciar servicios (PostgreSQL + Redis)
Write-Host "🐳 Iniciando servicios de desarrollo..." -ForegroundColor Cyan
docker-compose -f docker-compose.dev.yml up -d

Write-Host ""
Write-Host "✅ Servicios iniciados:" -ForegroundColor Green
Write-Host "  📊 PostgreSQL: localhost:5432" -ForegroundColor White
Write-Host "     - Database: vintage_music" -ForegroundColor Gray
Write-Host "     - User: vintage_user" -ForegroundColor Gray
Write-Host "     - Password: vintage_password_2024" -ForegroundColor Gray
Write-Host ""
Write-Host "  🔴 Redis: localhost:6379" -ForegroundColor White
Write-Host ""
Write-Host "💡 Para ver los logs: docker-compose -f docker-compose.dev.yml logs -f" -ForegroundColor Yellow
Write-Host "💡 Para detener: docker-compose -f docker-compose.dev.yml down" -ForegroundColor Yellow
