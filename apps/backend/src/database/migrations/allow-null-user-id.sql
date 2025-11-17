-- Asegurar que la columna user_id permita NULL en artists
ALTER TABLE IF EXISTS artists
  ALTER COLUMN user_id DROP NOT NULL;


