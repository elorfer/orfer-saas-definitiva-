-- Sincronizar flag is_featured con featured para artistas existentes
UPDATE artists
SET is_featured = TRUE
WHERE featured = TRUE
  AND (is_featured IS DISTINCT FROM TRUE);







