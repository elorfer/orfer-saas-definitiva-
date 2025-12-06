# Ejecutar Migración SQL - Campo is_verified

## Opción 1: Usando psql (Recomendado)

```bash
# Conectar a la base de datos
psql -U vintage_user -d vintage_music -h localhost -p 5432

# O usando DATABASE_URL completa
psql "postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music"

# Luego ejecutar:
\i migrations/add_is_verified_to_artists.sql
```

## Opción 2: Ejecutar SQL directamente

```bash
psql -U vintage_user -d vintage_music -h localhost -p 5432 -f migrations/add_is_verified_to_artists.sql
```

## Opción 3: Usando Docker (si usas Docker)

```bash
docker exec -i vintage-music-postgres psql -U vintage_user -d vintage_music < migrations/add_is_verified_to_artists.sql
```

## Verificar que funcionó:

```sql
-- Verificar que la columna existe
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'artists' AND column_name = 'is_verified';

-- Verificar que el índice existe
SELECT indexname FROM pg_indexes WHERE tablename = 'artists' AND indexname = 'idx_artists_is_verified';

-- Ver artistas verificados
SELECT id, stage_name, is_verified, verification_status 
FROM artists 
WHERE is_verified = TRUE;
```



