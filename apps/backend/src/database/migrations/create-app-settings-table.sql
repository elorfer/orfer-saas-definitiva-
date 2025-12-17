-- Migración: Crear tabla app_settings para configuraciones globales
-- Fecha: 2024-12-17
-- Descripción: Almacena configuraciones key-value para la aplicación

-- Crear tabla app_settings
CREATE TABLE IF NOT EXISTS app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) NOT NULL UNIQUE,
    value INTEGER NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Crear índice para búsquedas rápidas por key
CREATE INDEX IF NOT EXISTS idx_app_settings_key ON app_settings(key);

-- Insertar valores por defecto
INSERT INTO app_settings (key, value, description) 
VALUES (
    'ad_frequency', 
    3, 
    'Número de canciones que se reproducen entre cada anuncio'
)
ON CONFLICT (key) DO NOTHING;

-- Comentarios para documentación
COMMENT ON TABLE app_settings IS 'Configuraciones globales de la aplicación';
COMMENT ON COLUMN app_settings.key IS 'Identificador único de la configuración';
COMMENT ON COLUMN app_settings.value IS 'Valor numérico de la configuración';
COMMENT ON COLUMN app_settings.description IS 'Descripción de la configuración para documentación';


