-- Índices para optimizar consultas de contenido destacado
-- Estos índices mejoran significativamente el rendimiento de las consultas WHERE is_featured = true

-- Índice compuesto para canciones destacadas (is_featured + status para filtros comunes)
CREATE INDEX IF NOT EXISTS idx_songs_featured_status 
ON songs(is_featured, status) 
WHERE is_featured = true AND status = 'published';

-- Índice para artistas destacados
CREATE INDEX IF NOT EXISTS idx_artists_featured 
ON artists(is_featured) 
WHERE is_featured = true;

-- Índice compuesto para playlists destacadas (is_featured + visibility)
CREATE INDEX IF NOT EXISTS idx_playlists_featured_visibility 
ON playlists(is_featured, visibility) 
WHERE is_featured = true AND visibility = 'public';

-- Índice adicional para ordenamiento por fecha de creación
CREATE INDEX IF NOT EXISTS idx_songs_featured_created 
ON songs(created_at DESC) 
WHERE is_featured = true AND status = 'published';

CREATE INDEX IF NOT EXISTS idx_artists_featured_created 
ON artists(created_at DESC) 
WHERE is_featured = true;

CREATE INDEX IF NOT EXISTS idx_playlists_featured_created 
ON playlists(created_at DESC) 
WHERE is_featured = true AND visibility = 'public';


