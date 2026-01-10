#!/bin/bash

# 💾 BACKUP AUTOMATIZADO DE BASE DE DATOS PostgreSQL
# Este script crea backups diarios de tu base de datos y los guarda localmente

# ═══════════════════════════════════════════════════════════════
# CONFIGURACIÓN (ajusta según tu .env)
# ═══════════════════════════════════════════════════════════════

# Directorio donde se guardarán los backups (ajustar según tu sistema)
BACKUP_DIR="./backups/db"

# Cargar variables de entorno desde .env.local o .env
if [ -f .env.local ]; then
  export $(cat .env.local | grep -v '^#' | xargs)
elif [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Información de la base de datos (desde .env)
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_DATABASE:-vintage_music}"
DB_USER="${DB_USERNAME:-vintage_user}"
DB_PASSWORD="${DB_PASSWORD:-vintage_password_2024}"

# Nombre del archivo de backup (formato: backup_YYYYMMDD_HHMMSS.sql)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql"

# ═══════════════════════════════════════════════════════════════
# EJECUCIÓN del BACKUP
# ═══════════════════════════════════════════════════════════════

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 INICIANDO BACKUP DE BASE DE DATOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
date

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Exportar password para pg_dump
export PGPASSWORD="$DB_PASSWORD"

# Ejecutar pg_dump
echo "📊 Base de datos: $DB_NAME"
echo "🖥️  Host: $DB_HOST:$DB_PORT"
echo "💾 Guardando en: $BACKUP_FILE"
echo ""

pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -F c -b -v -f "$BACKUP_FILE" "$DB_NAME"

# Verificar si el backup fue exitoso
if [ $? -eq 0 ]; then
  # Calcular tamaño del archivo
  BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ BACKUP COMPLETADO EXITOSAMENTE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📁 Archivo: $BACKUP_FILE"
  echo "📦 Tamaño: $BACKUP_SIZE"
  date
  
  # Limpiare backups antiguos (mantener solo los últimos 7 días)
  find "$BACKUP_DIR" -name "backup_*.sql" -type f -mtime +7 -delete
  echo "🗑️  Backups antiguos eliminados (>7 días)"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "❌ ERROR: Backup falló"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi

# Limpiar variable de password
unset PGPASSWORD

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
