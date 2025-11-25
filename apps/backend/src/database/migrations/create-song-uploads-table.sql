-- Migration: Crear tabla song_uploads para tracking e idempotencia
-- Ejecutar con: npm run migration:run

CREATE TYPE upload_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'cancelled');

CREATE TABLE IF NOT EXISTS song_uploads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    upload_id VARCHAR(255) UNIQUE NOT NULL,
    user_id UUID NOT NULL,
    status upload_status NOT NULL DEFAULT 'pending',
    audio_file_key VARCHAR(500),
    cover_file_key VARCHAR(500),
    song_id UUID,
    title VARCHAR(200),
    artist_id UUID,
    album_id UUID,
    genre_id UUID,
    error TEXT,
    metadata JSONB,
    job_id VARCHAR(255),
    retry_count INTEGER DEFAULT 0,
    compensation_applied BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_song_uploads_upload_id ON song_uploads(upload_id);
CREATE INDEX IF NOT EXISTS idx_song_uploads_user_status ON song_uploads(user_id, status);
CREATE INDEX IF NOT EXISTS idx_song_uploads_created_at ON song_uploads(created_at);
CREATE INDEX IF NOT EXISTS idx_song_uploads_song_id ON song_uploads(song_id) WHERE song_id IS NOT NULL;

-- Comentarios
COMMENT ON TABLE song_uploads IS 'Tabla para tracking de uploads de canciones con soporte para idempotencia';
COMMENT ON COLUMN song_uploads.upload_id IS 'ID único para idempotencia (generado por cliente o servidor)';
COMMENT ON COLUMN song_uploads.audio_file_key IS 'Clave del archivo de audio en storage';
COMMENT ON COLUMN song_uploads.cover_file_key IS 'Clave del archivo de portada en storage';
COMMENT ON COLUMN song_uploads.job_id IS 'ID del job de BullMQ';
COMMENT ON COLUMN song_uploads.compensation_applied IS 'Indica si se aplicó limpieza de archivos (SAGA pattern)';










