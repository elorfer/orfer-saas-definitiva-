-- Migración para agregar índice en is_featured para optimizar consultas
-- Esta migración mejora el rendimiento de las consultas de canciones destacadas

-- Crear índice en is_featured para consultas rápidas
CREATE INDEX IF NOT EXISTS idx_songs_is_featured ON songs(is_featured) WHERE is_featured = true;

-- Crear índice compuesto para consultas de canciones publicadas y destacadas
CREATE INDEX IF NOT EXISTS idx_songs_status_featured ON songs(status, is_featured) 
WHERE status = 'published';

-- Crear índice para ordenamiento por fecha de creación
CREATE INDEX IF NOT EXISTS idx_songs_created_at ON songs(created_at DESC);

-- Índice compuesto para búsquedas optimizadas (título, artista, género)
CREATE INDEX IF NOT EXISTS idx_songs_search ON songs(status, created_at DESC, is_featured DESC)
WHERE status = 'published';

-- Nota: Estos índices mejoran significativamente el rendimiento de:
-- 1. Obtener canciones destacadas
-- 2. Feed del home (destacadas + nuevas)
-- 3. Búsquedas filtradas por estado y featured
-- 4. Ordenamiento por fecha de creación
