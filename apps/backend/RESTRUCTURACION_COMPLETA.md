# Reestructuración Completa del Backend para App Flutter

## Resumen de Cambios

Este documento resume todos los cambios realizados para optimizar el backend para la app Flutter, incluyendo endpoints limpios, paginación, filtros y el sistema de contenido destacado.

## Archivos Creados

### 1. DTOs (Data Transfer Objects)

- **`apps/backend/src/modules/songs/dto/song-response.dto.ts`**
  - `SongResponseDto`: DTO optimizado para respuestas de canciones
  - `PaginatedSongsResponseDto`: DTO para respuestas paginadas
  - `HomeFeedResponseDto`: DTO para el feed del home

- **`apps/backend/src/modules/songs/dto/song-query.dto.ts`**
  - `SongQueryDto`: DTO para query parameters de búsqueda

### 2. Mappers

- **`apps/backend/src/modules/songs/mappers/song.mapper.ts`**
  - `SongMapper`: Serializador que convierte entidades Song a DTOs limpios
  - Elimina datos innecesarios y formatea la respuesta para Flutter

### 3. Servicios

- **`apps/backend/src/modules/songs/songs.service.ts`** (Actualizado)
  - Nuevos métodos agregados:
    - `getPublishedSongs()`: Obtiene canciones publicadas con filtros opcionales
    - `getFeaturedSongs()`: Obtiene canciones destacadas
    - `getHomeFeed()`: Obtiene el feed del home (destacadas + nuevas)
    - `toggleFeatured()`: Marca/desmarca una canción como destacada
    - `findOneOptimized()`: Obtiene una canción por ID optimizada para Flutter

### 4. Controllers

- **`apps/backend/src/modules/songs/public-songs.controller.ts`** (Reescrito completamente)
  - `GET /api/v1/public/songs`: Endpoint principal con filtros
  - `GET /api/v1/public/songs/featured`: Canciones destacadas
  - `GET /api/v1/public/songs/home-feed`: Feed del home
  - `GET /api/v1/public/songs/:id`: Canción individual

- **`apps/backend/src/modules/songs/songs.controller.ts`** (Actualizado)
  - `POST /api/v1/songs/:id/feature`: Marcar como destacada
  - `DELETE /api/v1/songs/:id/feature`: Desmarcar como destacada
  - `PATCH /api/v1/songs/:id/feature`: Alternar estado destacado

### 5. Migraciones

- **`apps/backend/src/database/migrations/add-song-featured-index.sql`**
  - Índices creados para optimizar consultas:
    - `idx_songs_is_featured`: Índice en `is_featured`
    - `idx_songs_status_featured`: Índice compuesto en `status` e `is_featured`
    - `idx_songs_created_at`: Índice para ordenamiento por fecha
    - `idx_songs_search`: Índice compuesto para búsquedas

### 6. Documentación

- **`apps/backend/HOME_FEED.md`**: Documentación completa del flujo y endpoints
- **`apps/backend/examples/flutter-api-response-example.json`**: Ejemplos de respuestas JSON

## Endpoints Públicos (Sin Autenticación)

### 1. Obtener Canciones Publicadas

```
GET /api/v1/public/songs
```

**Query Parameters:**
- `page` (opcional, default: 1)
- `limit` (opcional, default: 20, max: 100)
- `featured` (opcional): true/false
- `artistId` (opcional)
- `genreId` (opcional)
- `search` (opcional): búsqueda por título o artista

### 2. Obtener Canciones Destacadas

```
GET /api/v1/public/songs/featured
```

**Query Parameters:**
- `page` (opcional, default: 1)
- `limit` (opcional, default: 20)

### 3. Obtener Home Feed

```
GET /api/v1/public/songs/home-feed
```

**Query Parameters:**
- `featuredLimit` (opcional, default: 10)
- `newSongsLimit` (opcional, default: 20)

### 4. Obtener Canción Individual

```
GET /api/v1/public/songs/:id
```

## Endpoints de Administración (Con Autenticación)

### 1. Marcar como Destacada

```
POST /api/v1/songs/:id/feature
Authorization: Bearer <token>
```

### 2. Desmarcar como Destacada

```
DELETE /api/v1/songs/:id/feature
Authorization: Bearer <token>
```

### 3. Alternar Estado Destacado

```
PATCH /api/v1/songs/:id/feature
Authorization: Bearer <token>
Content-Type: application/json

{
  "featured": true
}
```

## Modelo de Datos

### Campo `isFeatured` en Song Entity

El campo `isFeatured` ya existía en el modelo:

```typescript
@Column({ name: 'is_featured', default: false })
isFeatured: boolean;
```

## Optimizaciones Implementadas

### 1. Base de Datos

- Índices creados para optimizar consultas
- Consultas optimizadas con QueryBuilder de TypeORM
- Paginación a nivel de BD

### 2. Serialización

- SongMapper elimina datos innecesarios
- Solo incluye campos necesarios para Flutter
- URLs formateadas correctamente
- Duración formateada (MM:SS)

### 3. Performance

- Join selectivo solo de relaciones necesarias
- Filtros opcionales aplicados condicionalmente
- Respuestas paginadas para reducir payload

## Ejecutar Migraciones

### Opción 1: Ejecutar SQL directamente

```bash
docker exec -i vintage-music-postgres psql -U <usuario> -d vintage_music_db < apps/backend/src/database/migrations/add-song-featured-index.sql
```

### Opción 2: Ejecutar comandos SQL individuales

```sql
CREATE INDEX IF NOT EXISTS idx_songs_is_featured ON songs(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_songs_status_featured ON songs(status, is_featured) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_songs_created_at ON songs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_songs_search ON songs(status, created_at DESC, is_featured DESC) WHERE status = 'published';
```

## Pruebas

### Ejemplo de Request - Home Feed

```http
GET /api/v1/public/songs/home-feed?featuredLimit=10&newSongsLimit=20
```

### Ejemplo de Request - Canciones Destacadas

```http
GET /api/v1/public/songs/featured?page=1&limit=20
```

### Ejemplo de Request - Búsqueda

```http
GET /api/v1/public/songs?search=rock&page=1&limit=20
```

## Estructura de Respuesta

Todas las respuestas siguen un formato consistente:

```json
{
  "songs": [...],
  "total": 54,
  "page": 1,
  "limit": 20,
  "totalPages": 3,
  "hasNext": true,
  "hasPrevious": false
}
```

O para el home feed:

```json
{
  "featured": [...],
  "newSongs": [...],
  "pagination": {
    "page": 1,
    "limit": 30,
    "total": 54,
    "totalPages": 2
  }
}
```

## Notas Importantes

1. **Sin autenticación**: Los endpoints públicos (`/api/v1/public/songs`) NO requieren autenticación
2. **Límites**: Máximo 100 elementos por página
3. **Ordenamiento**: Destacadas siempre aparecen primero cuando se filtran
4. **Performance**: Índices mejoran significativamente las consultas
5. **Consistencia**: Todas las respuestas siguen el mismo formato

## Próximos Pasos Recomendados

1. Implementar caching con Redis para respuestas frecuentes
2. Agregar rate limiting para prevenir abuso
3. Implementar WebSockets para actualizaciones en tiempo real
4. Agregar más filtros (fecha, popularidad, etc.)
5. Implementar versionado de API

## Archivos Modificados

- `apps/backend/src/modules/songs/songs.service.ts`
- `apps/backend/src/modules/songs/songs.controller.ts`
- `apps/backend/src/modules/songs/public-songs.controller.ts`

## Compatibilidad

Todos los cambios son retrocompatibles. Los endpoints antiguos siguen funcionando, y se agregaron nuevos endpoints optimizados para Flutter sin afectar funcionalidad existente.
