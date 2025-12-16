-- Migración: Sistema de Streams estilo Spotify
-- Fecha: 2024

-- Tabla de streams individuales
CREATE TABLE IF NOT EXISTS streams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    duration_listened INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_streams_user_song_created ON streams(user_id, song_id, created_at);
CREATE INDEX IF NOT EXISTS idx_streams_song_created ON streams(song_id, created_at);
CREATE INDEX IF NOT EXISTS idx_streams_user_created ON streams(user_id, created_at);

-- Tabla de sesiones de escucha (para tracking de progreso y anti-fraude)
CREATE TABLE IF NOT EXISTS user_listening_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    max_progress_ms BIGINT DEFAULT 0,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_progress_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_stream_validated BOOLEAN DEFAULT FALSE,
    stream_validated_at TIMESTAMP NULL,
    is_paused BOOLEAN DEFAULT FALSE,
    pause_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, song_id)
);

-- Índices para sesiones
CREATE INDEX IF NOT EXISTS idx_sessions_user_song ON user_listening_sessions(user_id, song_id);
CREATE INDEX IF NOT EXISTS idx_sessions_created ON user_listening_sessions(created_at);

-- Comentarios
COMMENT ON TABLE streams IS 'Registra streams válidos (30+ segundos) de usuarios';
COMMENT ON TABLE user_listening_sessions IS 'Tracking de progreso de reproducción para validación de streams';
COMMENT ON COLUMN user_listening_sessions.max_progress_ms IS 'Máximo progreso alcanzado en milisegundos';
COMMENT ON COLUMN user_listening_sessions.is_stream_validated IS 'Si ya se registró como stream válido';
COMMENT ON COLUMN streams.duration_listened IS 'Duración escuchada en segundos (mínimo 30)';

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_listening_sessions_updated_at 
    BEFORE UPDATE ON user_listening_sessions 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();




















