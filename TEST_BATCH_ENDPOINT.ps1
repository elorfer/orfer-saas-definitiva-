# 🧪 Script de Prueba Rápida para el Nuevo Endpoint de Batching (PowerShell)
# Uso: .\TEST_BATCH_ENDPOINT.ps1 [SONG_ID]

param(
    [string]$SongId = "1f4a62b3-e5d9-402e-81d8-a281db16db73"  # ID de ejemplo
)

# Configuración
$BackendUrl = "http://localhost:3001"
$Endpoint = "/public/songs/playlist/generate"

Write-Host "🧪 Probando Endpoint de Batching" -ForegroundColor Yellow
Write-Host "URL: $BackendUrl$Endpoint"
Write-Host "Semilla: $SongId"
Write-Host ""

# Test 1: Básico
Write-Host "Test 1: Solicitud básica (4 recomendaciones)" -ForegroundColor Green
$response1 = Invoke-RestMethod -Uri "$BackendUrl$Endpoint?seed=$SongId&count=4" -Method Get
$response1 | ConvertTo-Json -Depth 10
Write-Host ""

# Test 2: Con count diferente
Write-Host "Test 2: Solicitud con count=8" -ForegroundColor Green
$response2 = Invoke-RestMethod -Uri "$BackendUrl$Endpoint?seed=$SongId&count=8" -Method Get
Write-Host "Count: $($response2.count)"
Write-Host "Requested: $($response2.requested)"
Write-Host "Songs recibidas: $($response2.songs.Count)"
Write-Host ""

# Test 3: Con excludeIds
Write-Host "Test 3: Solicitud con excludeIds" -ForegroundColor Green
$excludeIds = "1f4a62b3-e5d9-402e-81d8-a281db16db73,063edf5b-05ea-42f6-bdc3-dfc225fc78e8"
$response3 = Invoke-RestMethod -Uri "$BackendUrl$Endpoint?seed=$SongId&count=4&excludeIds=$excludeIds" -Method Get
Write-Host "Count: $($response3.count)"
Write-Host "Requested: $($response3.requested)"
Write-Host "Songs recibidas: $($response3.songs.Count)"
Write-Host ""

# Test 4: Medir tiempo de respuesta
Write-Host "Test 4: Medición de tiempo" -ForegroundColor Green
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$null = Invoke-RestMethod -Uri "$BackendUrl$Endpoint?seed=$SongId&count=4" -Method Get
$stopwatch.Stop()
Write-Host "Tiempo de respuesta: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Yellow
Write-Host ""

# Test 5: Verificar estructura de respuesta
Write-Host "Test 5: Verificar estructura de respuesta" -ForegroundColor Green
$response5 = Invoke-RestMethod -Uri "$BackendUrl$Endpoint?seed=$SongId&count=4" -Method Get

if ($response5.songs) {
    Write-Host "✅ Campo 'songs' presente" -ForegroundColor Green
} else {
    Write-Host "❌ Campo 'songs' faltante" -ForegroundColor Red
}

if ($response5.count -ne $null) {
    Write-Host "✅ Campo 'count' presente" -ForegroundColor Green
} else {
    Write-Host "❌ Campo 'count' faltante" -ForegroundColor Red
}

if ($response5.algorithm) {
    Write-Host "✅ Campo 'algorithm' presente" -ForegroundColor Green
} else {
    Write-Host "❌ Campo 'algorithm' faltante" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Pruebas completadas" -ForegroundColor Yellow













