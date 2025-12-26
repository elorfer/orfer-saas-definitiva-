-- Migración: Añadir columnas de análisis de audio para recomendaciones avanzadas
-- Fecha: 2024-12-20

-- Añadir columnas de metadatos de audio
ALTER TABLE songs ADD COLUMN IF NOT EXISTS bpm INTEGER NULL;
ALTER TABLE songs ADD COLUMN IF NOT EXISTS musical_key VARCHAR(10) NULL;
ALTER TABLE songs ADD COLUMN IF NOT EXISTS energy FLOAT NULL;
ALTER TABLE songs ADD COLUMN IF NOT EXISTS danceability FLOAT NULL;
ALTER TABLE songs ADD COLUMN IF NOT EXISTS valence FLOAT NULL;

-- Comentarios explicativos
COMMENT ON COLUMN songs.bpm IS 'Beats por minuto (60-200)';
COMMENT ON COLUMN songs.musical_key IS 'Tonalidad musical (ej: C, Am, F#m)';
COMMENT ON COLUMN songs.energy IS 'Energía de la canción (0.0-1.0)';
COMMENT ON COLUMN songs.danceability IS 'Danceabilidad (0.0-1.0)';
COMMENT ON COLUMN songs.valence IS 'Valencia/Positividad (0.0-1.0)';

-- Índices para optimizar búsquedas por similitud
CREATE INDEX IF NOT EXISTS idx_songs_bpm ON songs(bpm) WHERE bpm IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_songs_musical_key ON songs(musical_key) WHERE musical_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_songs_energy ON songs(energy) WHERE energy IS NOT NULL;

-- Índice compuesto para búsquedas de similitud
CREATE INDEX IF NOT EXISTS idx_songs_audio_features ON songs(bpm, musical_key, energy) 
WHERE bpm IS NOT NULL OR musical_key IS NOT NULL;
