# Script de Verificación - Facebook Login Configuration
# Ejecuta este script para verificar que la configuración esté completa

Write-Host "🔍 Verificando configuración de Facebook Login..." -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()

# 1. Verificar que strings.xml existe
$stringsPath = "android\app\src\main\res\values\strings.xml"
if (Test-Path $stringsPath) {
    Write-Host "✅ strings.xml encontrado" -ForegroundColor Green
    
    # Leer contenido
    $content = Get-Content $stringsPath -Raw
    
    # 2. Verificar que NO tenga placeholders
    if ($content -match "XXXXXXXXXX") {
        $errors += "❌ CRÍTICO: strings.xml todavía tiene placeholders (XXXXXXXXXX)"
        $errors += "   Debes reemplazar XXXXXXXXXX con tu Facebook App ID real"
    } else {
        Write-Host "✅ Facebook App ID configurado (sin placeholders)" -ForegroundColor Green
    }
    
    if ($content -match "YYYYYYYYYY") {
        $errors += "❌ CRÍTICO: strings.xml todavía tiene placeholders (YYYYYYYYYY)"
        $errors += "   Debes reemplazar YYYYYYYYYY con tu Facebook Client Token real"
    } else {
        Write-Host "✅ Facebook Client Token configurado (sin placeholders)" -ForegroundColor Green
    }
    
    # 3. Verificar que tenga los campos necesarios
    if ($content -match 'facebook_app_id') {
        Write-Host "✅ facebook_app_id definido" -ForegroundColor Green
    } else {
        $errors += "❌ facebook_app_id NO encontrado en strings.xml"
    }
    
    if ($content -match 'fb_login_protocol_scheme') {
        Write-Host "✅ fb_login_protocol_scheme definido" -ForegroundColor Green
    } else {
        $errors += "❌ fb_login_protocol_scheme NO encontrado en strings.xml"
    }
    
    if ($content -match 'facebook_client_token') {
        Write-Host "✅ facebook_client_token definido" -ForegroundColor Green
    } else {
        $errors += "❌ facebook_client_token NO encontrado en strings.xml"
    }
} else {
    $errors += "❌ CRÍTICO: strings.xml NO encontrado en $stringsPath"
}

Write-Host ""

# 4. Verificar AndroidManifest.xml
$manifestPath = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
    Write-Host "✅ AndroidManifest.xml encontrado" -ForegroundColor Green
    
    $manifestContent = Get-Content $manifestPath -Raw
    
    if ($manifestContent -match 'com.facebook.sdk.ApplicationId') {
        Write-Host "✅ Facebook SDK ApplicationId configurado en manifest" -ForegroundColor Green
    } else {
        $errors += "❌ Facebook SDK ApplicationId NO encontrado en AndroidManifest.xml"
    }
    
    if ($manifestContent -match 'com.facebook.FacebookActivity') {
        Write-Host "✅ FacebookActivity configurada en manifest" -ForegroundColor Green
    } else {
        $errors += "❌ FacebookActivity NO encontrada en AndroidManifest.xml"
    }
    
    if ($manifestContent -match 'com.facebook.katana') {
        Write-Host "✅ Query para Facebook app configurada" -ForegroundColor Green
    } else {
        $warnings += "⚠️  Query para Facebook app NO encontrada (puede afectar si Facebook está instalado)"
    }
} else {
    $errors += "❌ CRÍTICO: AndroidManifest.xml NO encontrado"
}

Write-Host ""

# 5. Verificar MainActivity.kt
$mainActivityPath = "android\app\src\main\kotlin\com\struky\app\MainActivity.kt"
if (Test-Path $mainActivityPath) {
    Write-Host "✅ MainActivity.kt en el package correcto (com.struky.app)" -ForegroundColor Green
} else {
    $errors += "❌ MainActivity.kt NO encontrado en el package correcto"
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White

# Mostrar resumen
if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host ""
    Write-Host "🎉 ¡CONFIGURACIÓN COMPLETA!" -ForegroundColor Green
    Write-Host "   Tu app está lista para usar Facebook Login" -ForegroundColor Green
    Write-Host ""
    Write-Host "📱 Próximos pasos:" -ForegroundColor Cyan
    Write-Host "   1. Ejecuta: flutter clean" -ForegroundColor White
    Write-Host "   2. Ejecuta: flutter run" -ForegroundColor White
    Write-Host "   3. Prueba el login con Facebook" -ForegroundColor White
    Write-Host ""
} else {
    if ($errors.Count -gt 0) {
        Write-Host ""
        Write-Host "❌ ERRORES ENCONTRADOS:" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "   $error" -ForegroundColor Red
        }
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠️  ADVERTENCIAS:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "   $warning" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "📖 Lee el archivo FACEBOOK_LOGIN_SETUP.md para instrucciones completas" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
