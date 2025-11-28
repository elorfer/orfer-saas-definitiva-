-- Migración: Agregar columna genres a la tabla songs
-- Fecha: 2024
-- Descripción: Agrega un campo de texto para almacenar géneros musicales como array separado por comas

-- Verificar si la columna ya existe antes de agregarla
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'songs' 
        AND column_name = 'genres'
    ) THEN
        -- Agregar la columna genres como TEXT (TypeORM simple-array lo almacena como string separado por comas)
        ALTER TABLE songs 
        ADD COLUMN genres TEXT;
        
        -- Comentario en la columna para documentación
        COMMENT ON COLUMN songs.genres IS 'Array de géneros musicales separados por comas (ej: "Reggaeton,Trap Latino")';
        
        RAISE NOTICE 'Columna genres agregada exitosamente a la tabla songs';
    ELSE
        RAISE NOTICE 'La columna genres ya existe en la tabla songs';
    END IF;
END $$;






