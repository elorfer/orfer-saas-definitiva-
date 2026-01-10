# 💾 BACKUP AUTOMATIZADO DE BASE DE DATOS PostgreSQL (Windows PowerShell)
# Este script crea backups diarios de tu base de datos y los guarda localmente

# ═══════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════

# Directorio donde se guardarán los backups
$BACKUP_DIR = "$PSScriptRoot\..\backups\db"

# Lee variables de .env.local o .env
$envFile = "$PSScriptRoot\..\.env.local"
if (-Not (Test-Path $envFile)) {
    $envFile = "$PSScriptRoot\..\.env"
}

# Cargar variables desde .env
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -notmatch '^#' -and $_ -match '=') {
            $name, $value = $_ -split '=', 2
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

# Información de la base de datos
$DB_HOST = if ($env:DB_HOST) { $env:DB_HOST } else { "localhost" }
$DB_PORT = if ($env:DB_PORT) { $env:DB_PORT } else { "5432" }
$DB_NAME = if ($env:DB_DATABASE) { $env:DB_DATABASE } else { "vintage_music" }
$DB_USER = if ($env:DB_USERNAME) { $env:DB_USERNAME } else { "vintage_user" }
$DB_PASSWORD = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { "vintage_password_2024" }

# Nombre del archivo de backup
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_FILE = "$BACKUP_DIR\backup_$TIMESTAMP.sql"

# ═══════════════════════════════════════════════════════════════
# EJECUCIÓN del BACKUP
# ═══════════════════════════════════════════════════════════════

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💾 INICIANDO BACKUP DE BASE DE DATOS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# Crear directorio de backups si no existe
if (-Not (Test-Path $BACKUP_DIR)) {
    New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
}

# Configurar password
$env:PGPASSWORD = $DB_PASSWORD

Write-Host "📊 Base de datos: $DB_NAME" -ForegroundColor White
Write-Host "🖥️  Host: ${DB_HOST}:${DB_PORT}" -ForegroundColor White
Write-Host "💾 Guardando en: $BACKUP_FILE" -ForegroundColor White
Write-Host ""
Write-Host "⏳ Ejecutando pg_dump..." -ForegroundColor Yellow

# Ejecutar pg_dump
# Nota: Asegúrate de que pg_dump esté en tu PATH o especifica la ruta completa
# Ejemplo: C:\Program Files\PostgreSQL\15\bin\pg_dump.exe
try {
    & pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -F c -b -v -f $BACKUP_FILE $DB_NAME
    
    if ($LASTEXITCODE -eq 0) {
        $backupSize = (Get-Item $BACKUP_FILE).Length / 1MB
        $backupSizeFormatted = "{0:N2} MB" -f $backupSize
        
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host "✅ BACKUP COMPLETADO EXITOSAMENTE" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host "📁 Archivo: $BACKUP_FILE" -ForegroundColor White
        Write-Host "📦 Tamaño: $backupSizeFormatted" -ForegroundColor White
        Write-Host "🕐 Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
        
        # Limpiar backups antiguos (mantener solo últimos 7 días)
        $cutoffDate = (Get-Date).AddDays(-7)
        Get-ChildItem -Path $BACKUP_DIR -Filter "backup_*.sql" | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate } | 
            Remove-Item -Force
        
        Write-Host "🗑️  Backups antiguos eliminados (>7 días)" -ForegroundColor Gray
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    } else {
        throw "pg_dump falló con código de salida: $LASTEXITCODE"
    }
} catch {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
    Write-Host "❌ ERROR: Backup falló" -ForegroundColor Red
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    # Limpiar variable de password
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
