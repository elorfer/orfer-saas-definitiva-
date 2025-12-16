-- Migración: Agregar campo image_url a la tabla genres
-- Fecha: 2024
-- Descripción: Agrega el campo image_url para almacenar las URLs de las imágenes de los géneros musicales

-- Agregar columna image_url si no existe
ALTER TABLE genres 
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Comentario en la columna
COMMENT ON COLUMN genres.image_url IS 'URL de la imagen del género musical';













