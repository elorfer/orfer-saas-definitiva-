-- Migración: Agregar campo is_verified a la tabla artists
-- Fecha: 2025-12-06
-- Descripción: Agregar campo is_verified para sistema de verificación de artistas al estilo Spotify

-- Agregar columna is_verified si no existe
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'artists' 
    AND column_name = 'is_verified'
  ) THEN
    ALTER TABLE artists 
    ADD COLUMN is_verified BOOLEAN DEFAULT FALSE NOT NULL;
    
    -- Sincronizar datos existentes: si verification_status es true, is_verified también
    UPDATE artists 
    SET is_verified = TRUE 
    WHERE verification_status = TRUE;
    
    -- Crear índice para búsquedas rápidas de artistas verificados
    CREATE INDEX IF NOT EXISTS idx_artists_is_verified ON artists(is_verified) WHERE is_verified = TRUE;
    
    RAISE NOTICE 'Columna is_verified agregada exitosamente';
  ELSE
    RAISE NOTICE 'La columna is_verified ya existe';
  END IF;
END $$;

-- Comentario en la columna
COMMENT ON COLUMN artists.is_verified IS 'Indica si el artista está verificado (badge azul tipo Spotify)';











