#!/usr/bin/env pwsh
# Script de Verificacion: RevenueCat Integration
Write-Host "=== VERIFICACION DE INTEGRACION REVENUECAT - STRUKY ===" -ForegroundColor Cyan
Write-Host ""

$errors = 0
$warnings = 0

# Verificar archivos de Backend
Write-Host "1. Verificando archivos de Backend..." -ForegroundColor Yellow

$backendFiles = @(
    "apps\backend\src\migrations\1736458800000-AddRevenueCatFieldsToUsers.ts",
    "apps\backend\src\modules\payments\revenuecat.service.ts",
    "apps\backend\src\modules\payments\revenuecat-webhook.controller.ts"
)

foreach ($file in $backendFiles) {
    if (Test-Path $file) {
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  FALTA: $file" -ForegroundColor Red
        $errors++
    }
}

# Verificar archivos de Frontend
Write-Host ""
Write-Host "2. Verificando archivos de Frontend..." -ForegroundColor Yellow

if (Test-Path "apps\frontend\lib\core\services\revenuecat_service.dart") {
    Write-Host "  OK: revenuecat_service.dart" -ForegroundColor Green
} else {
    Write-Host "  FALTA: revenuecat_service.dart" -ForegroundColor Red
    $errors++
}

if (Test-Path "apps\frontend\pubspec.yaml") {
    $pubspecContent = Get-Content "apps\frontend\pubspec.yaml" -Raw
    if ($pubspecContent -match "purchases_flutter") {
        Write-Host "  OK: purchases_flutter en pubspec.yaml" -ForegroundColor Green
    } else {
        Write-Host "  FALTA: purchases_flutter en pubspec.yaml" -ForegroundColor Red
        $errors++
    }
}

# Verificar documentacion
Write-Host ""
Write-Host "3. Verificando documentacion..." -ForegroundColor Yellow

$docs = @(
    "GUIA_REVENUECAT_GOOGLE_CLOUD.md",
    "GUIA_PRUEBAS_SANDBOX_REVENUECAT.md",
    "INTEGRACION_REVENUECAT_COMPLETA.md",
    "RESUMEN_REVENUECAT.md"
)

foreach ($doc in $docs) {
    if (Test-Path $doc) {
        Write-Host "  OK: $doc" -ForegroundColor Green
    } else {
        Write-Host "  ADVERTENCIA: $doc no encontrado" -ForegroundColor Yellow
        $warnings++
    }
}

# Resumen
Write-Host ""
Write-Host "=== RESUMEN DE VERIFICACION ===" -ForegroundColor Cyan
Write-Host ""

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "TODO PERFECTO! La integracion esta lista." -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximos pasos:" -ForegroundColor Cyan
    Write-Host "  1. Configurar API Keys de RevenueCat" -ForegroundColor White
    Write-Host "  2. Ejecutar migracion de BD" -ForegroundColor White
    Write-Host "  3. Configurar Service Account en Google Cloud" -ForegroundColor White
    Write-Host "  4. Configurar Webhook en RevenueCat" -ForegroundColor White
    Write-Host ""
    exit 0
} elseif ($errors -eq 0) {
    Write-Host "Completado con $warnings advertencia(s)" -ForegroundColor Yellow
    exit 2
} else {
    Write-Host "FALLIDO con $errors error(es) y $warnings advertencia(s)" -ForegroundColor Red
    exit 1
}
