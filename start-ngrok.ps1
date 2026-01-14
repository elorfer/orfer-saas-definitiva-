# 🚀 Script para iniciar ngrok tunnel
# Uso: .\start-ngrok.ps1

Write-Host "🚀 Iniciando ngrok tunnel..." -ForegroundColor Green
Write-Host ""

# Verificar que ngrok está instalado
if (-not (Test-Path "C:\ngrok\ngrok.exe")) {
    Write-Host "❌ Error: ngrok no encontrado en C:\ngrok\" -ForegroundColor Red
    Write-Host "📥 Descárgalo de: https://ngrok.com/download" -ForegroundColor Yellow
    exit 1
}

# Iniciar tunnel
Write-Host "🔊 Iniciando tunnel para puerto 3000..." -ForegroundColor Cyan
Write-Host "🌐 Tu backend estará disponible públicamente" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  IMPORTANTE: Copia la URL 'Forwarding' que aparecerá abajo" -ForegroundColor Yellow
Write-Host "    Ejemplo: https://abc123.ngrok.io" -ForegroundColor Yellow
Write-Host ""

& "C:\ngrok\ngrok.exe" http 3000
