-- Migración: Agregar campos is_featured a songs y artists
-- Ejecutar este script en la base de datos si los campos no existen

-- Agregar is_featured a songs si no existe
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'songs' 
        AND column_name = 'is_featured'
    ) THEN
        ALTER TABLE songs ADD COLUMN is_featured BOOLEAN DEFAULT FALSE;
        CREATE INDEX IF NOT EXISTS idx_songs_is_featured ON songs(is_featured);
    END IF;
END $$;

-- Agregar is_featured a artists si no existe
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'artists' 
        AND column_name = 'is_featured'
    ) THEN
        ALTER TABLE artists ADD COLUMN is_featured BOOLEAN DEFAULT FALSE;
        CREATE INDEX IF NOT EXISTS idx_artists_is_featured ON artists(is_featured);
    END IF;
END $$;

-- Verificar que los campos fueron agregados
SELECT 
    table_name, 
    column_name, 
    data_type, 
    column_default
FROM information_schema.columns
WHERE table_name IN ('songs', 'artists', 'playlists')
AND column_name = 'is_featured'
ORDER BY table_name;


