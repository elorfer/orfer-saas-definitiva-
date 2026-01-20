-- Script para restaurar canciones desde archivos locales
-- Este script crea un artista y registra todas las canciones encontradas

BEGIN;

-- 1. Crear usuario artista si no existe
INSERT INTO users (id, email, username, password_hash, first_name, last_name, role, is_verified, is_active, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'struky.music@struky.com',
  'strukymusic',
  '$2b$10$EYpoMUywEKW/s7l8vZ91xeGS8Yahm8ICdBlcw5dI3iXRYZWQgpux2', -- password: admin123
  'Struky',
  'Music',
  'artist',
  true,
  true,
  NOW(),
  NOW()
)
ON CONFLICT (email) DO NOTHING;

-- 2. Obtener el ID del usuario
DO $$
DECLARE
  user_id_var uuid;
  artist_id_var uuid;
BEGIN
  -- Obtener el user_id
  SELECT id INTO user_id_var FROM users WHERE email = 'struky.music@struky.com';
  
  -- Crear perfil de artista si no existe
  INSERT INTO artists (id, user_id, stage_name, bio, verification_status, total_streams, total_followers, monthly_listeners, created_at, updated_at)
  VALUES (
    gen_random_uuid(),
    user_id_var,
    'Struky Music Collection',
    'Colección de música restaurada desde archivos locales',
    true,
    500000,
    10000,
    5000,
    NOW(),
    NOW()
  )
  ON CONFLICT DO NOTHING;
  
  -- Obtener el artist_id
  SELECT id INTO artist_id_var FROM artists WHERE user_id = user_id_var;
  
  RAISE NOTICE 'Usuario y artista creados exitosamente';
  RAISE NOTICE 'User ID: %', user_id_var;
  RAISE NOTICE 'Artist ID: %', artist_id_var;
END $$;

COMMIT;

-- Nota: Después de ejecutar este script, ejecuta el script Node.js para importar las canciones
