# Home Feed API - Documentación

## Descripción General

Este documento describe el flujo y los endpoints optimizados para la app Flutter para obtener canciones destacadas, nuevas y el feed del home.

## Arquitectura

### Flujo de Datos

```
Flutter App → Public Songs Controller → Songs Service → Song Mapper → Response DTO
```

### Componentes Principales

1. **PublicSongsController**: Controlador público sin autenticación para la app Flutter
2. **SongsService**: Servicio con lógica de negocio optimizada
3. **SongMapper**: Serializador que convierte entidades a DTOs limpios para Flutter
4. **DTOs**: Objetos de transferencia optimizados sin datos innecesarios

## Endpoints Disponibles

### 1. Obtener Canciones Publicadas (Principal)

**Endpoint:** `GET /api/v1/public/songs`

**Descripción:** Endpoint principal para obtener canciones publicadas con filtros opcionales.

**Query Parameters:**
- `page` (opcional, default: 1): Número de página
- `limit` (opcional, default: 20, max: 100): Elementos por página
- `featured` (opcional): Filtrar solo destacadas (true/false)
- `artistId` (opcional): Filtrar por artista
- `genreId` (opcional): Filtrar por género
- `search` (opcional): Búsqueda por título o artista

**Ejemplo de Request:**
```http
GET /api/v1/public/songs?page=1&limit=20&featured=false&search=rock
```

**Ejemplo de Response:**
```json
{
  "songs": [
    {
      "id": "uuid-here",
      "title": "Canción Ejemplo",
      "duration": 227,
      "durationFormatted": "3:47",
      "fileUrl": "http://localhost:3000/uploads/songs/audio.mp3",
      "coverArtUrl": "http://localhost:3000/uploads/covers/cover.png",
      "featured": false,
      "releaseDate": "2025-01-15T00:00:00.000Z",
      "totalStreams": 1250,
      "totalLikes": 45,
      "totalShares": 12,
      "createdAt": "2025-01-15T10:30:00.000Z",
      "artist": {
        "id": "artist-uuid",
        "stageName": "Rock Legend",
        "avatarUrl": "http://localhost:3000/uploads/avatars/avatar.jpg"
      },
      "album": {
        "id": "album-uuid",
        "title": "Álbum Ejemplo",
        "coverArtUrl": "http://localhost:3000/uploads/covers/album.png"
      },
      "genre": {
        "id": "genre-uuid",
        "name": "Rock",
        "colorHex": "#FF5733"
      }
    }
  ],
  "total": 54,
  "page": 1,
  "limit": 20,
  "totalPages": 3,
  "hasNext": true,
  "hasPrevious": false
}
```

### 2. Obtener Canciones Destacadas

**Endpoint:** `GET /api/v1/public/songs/featured`

**Descripción:** Retorna solo las canciones marcadas como destacadas.

**Query Parameters:**
- `page` (opcional, default: 1): Número de página
- `limit` (opcional, default: 20): Elementos por página

**Ejemplo de Request:**
```http
GET /api/v1/public/songs/featured?page=1&limit=10
```

**Ejemplo de Response:**
```json
{
  "songs": [
    {
      "id": "uuid-featured",
      "title": "Canción Destacada",
      "duration": 245,
      "durationFormatted": "4:05",
      "fileUrl": "http://localhost:3000/uploads/songs/featured.mp3",
      "coverArtUrl": "http://localhost:3000/uploads/covers/featured.png",
      "featured": true,
      "totalStreams": 5000,
      "totalLikes": 200,
      "totalShares": 50,
      "createdAt": "2025-01-10T00:00:00.000Z",
      "artist": {
        "id": "artist-uuid",
        "stageName": "Superstar",
        "avatarUrl": "http://localhost:3000/uploads/avatars/superstar.jpg"
      }
    }
  ],
  "total": 15,
  "page": 1,
  "limit": 10,
  "totalPages": 2,
  "hasNext": true,
  "hasPrevious": false
}
```

### 3. Obtener Home Feed

**Endpoint:** `GET /api/v1/public/songs/home-feed`

**Descripción:** Retorna el feed del home con canciones destacadas primero, seguidas de canciones nuevas. Optimizado para la pantalla principal de la app.

**Query Parameters:**
- `featuredLimit` (opcional, default: 10): Límite de canciones destacadas
- `newSongsLimit` (opcional, default: 20): Límite de canciones nuevas

**Ejemplo de Request:**
```http
GET /api/v1/public/songs/home-feed?featuredLimit=10&newSongsLimit=20
```

**Ejemplo de Response:**
```json
{
  "featured": [
    {
      "id": "uuid-featured-1",
      "title": "Canción Destacada 1",
      "duration": 245,
      "durationFormatted": "4:05",
      "fileUrl": "http://localhost:3000/uploads/songs/featured1.mp3",
      "coverArtUrl": "http://localhost:3000/uploads/covers/featured1.png",
      "featured": true,
      "totalStreams": 5000,
      "totalLikes": 200,
      "totalShares": 50,
      "createdAt": "2025-01-10T00:00:00.000Z",
      "artist": {
        "id": "artist-uuid-1",
        "stageName": "Superstar",
        "avatarUrl": "http://localhost:3000/uploads/avatars/superstar.jpg"
      }
    }
  ],
  "newSongs": [
    {
      "id": "uuid-new-1",
      "title": "Canción Nueva 1",
      "duration": 180,
      "durationFormatted": "3:00",
      "fileUrl": "http://localhost:3000/uploads/songs/new1.mp3",
      "coverArtUrl": "http://localhost:3000/uploads/covers/new1.png",
      "featured": false,
      "totalStreams": 150,
      "totalLikes": 10,
      "totalShares": 3,
      "createdAt": "2025-01-15T10:30:00.000Z",
      "artist": {
        "id": "artist-uuid-2",
        "stageName": "New Artist",
        "avatarUrl": "http://localhost:3000/uploads/avatars/newartist.jpg"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 30,
    "total": 54,
    "totalPages": 2
  }
}
```

### 4. Obtener Canción por ID

**Endpoint:** `GET /api/v1/public/songs/:id`

**Descripción:** Obtiene una canción específica por su ID (optimizado para Flutter).

**Ejemplo de Request:**
```http
GET /api/v1/public/songs/uuid-here
```

**Ejemplo de Response:**
```json
{
  "id": "uuid-here",
  "title": "Canción Ejemplo",
  "duration": 227,
  "durationFormatted": "3:47",
  "fileUrl": "http://localhost:3000/uploads/songs/audio.mp3",
  "coverArtUrl": "http://localhost:3000/uploads/covers/cover.png",
  "featured": false,
  "releaseDate": "2025-01-15T00:00:00.000Z",
  "totalStreams": 1250,
  "totalLikes": 45,
  "totalShares": 12,
  "createdAt": "2025-01-15T10:30:00.000Z",
  "artist": {
    "id": "artist-uuid",
    "stageName": "Rock Legend",
    "avatarUrl": "http://localhost:3000/uploads/avatars/avatar.jpg"
  },
  "album": {
    "id": "album-uuid",
    "title": "Álbum Ejemplo",
    "coverArtUrl": "http://localhost:3000/uploads/covers/album.png"
  },
  "genre": {
    "id": "genre-uuid",
    "name": "Rock",
    "colorHex": "#FF5733"
  }
}
```

## Endpoints de Administración (Requieren Autenticación)

### Marcar Canción como Destacada

**Endpoint:** `POST /api/v1/songs/:id/feature`

**Descripción:** Marca una canción como destacada.

**Headers:**
```
Authorization: Bearer <token>
```

**Ejemplo de Request:**
```http
POST /api/v1/songs/uuid-here/feature
```

### Desmarcar Canción como Destacada

**Endpoint:** `DELETE /api/v1/songs/:id/feature`

**Descripción:** Desmarca una canción como destacada.

**Headers:**
```
Authorization: Bearer <token>
```

**Ejemplo de Request:**
```http
DELETE /api/v1/songs/uuid-here/feature
```

### Alternar Estado Destacado

**Endpoint:** `PATCH /api/v1/songs/:id/feature`

**Descripción:** Alterna el estado destacado de una canción.

**Headers:**
```
Authorization: Bearer <token>
```

**Body:**
```json
{
  "featured": true
}
```

**Ejemplo de Request:**
```http
PATCH /api/v1/songs/uuid-here/feature
Content-Type: application/json

{
  "featured": true
}
```

## Optimizaciones Implementadas

### 1. Base de Datos

- **Índices creados:**
  - `idx_songs_is_featured`: Índice en `is_featured` para consultas rápidas de destacadas
  - `idx_songs_status_featured`: Índice compuesto en `status` e `is_featured` para consultas combinadas
  - `idx_songs_created_at`: Índice en `created_at` para ordenamiento rápido
  - `idx_songs_search`: Índice compuesto para búsquedas optimizadas

### 2. Serialización

- **SongMapper**: Elimina datos innecesarios y formatea la respuesta
- Solo incluye campos necesarios para la app Flutter
- URLs completas y formateadas
- Duración formateada (MM:SS)

### 3. Consultas Optimizadas

- Uso de QueryBuilder de TypeORM para consultas eficientes
- Join selectivo solo de relaciones necesarias
- Paginación implementada a nivel de BD
- Filtros opcionales aplicados condicionalmente

### 4. Estructura de Respuesta

- Formato consistente en todos los endpoints
- Información de paginación completa
- Metadatos útiles (hasNext, hasPrevious, totalPages)

## Modelo de Datos

### Song Entity (Entidad Completa)

```typescript
{
  id: string;
  artistId: string;
  albumId?: string;
  title: string;
  duration: number; // segundos
  fileUrl: string;
  coverArtUrl?: string;
  lyrics?: string;
  genreId?: string;
  trackNumber?: number;
  status: 'draft' | 'published' | 'archived';
  isExplicit: boolean;
  releaseDate?: Date;
  totalStreams: number;
  totalLikes: number;
  totalShares: number;
  isFeatured: boolean; // ← Campo clave para destacadas
  createdAt: Date;
  updatedAt: Date;
}
```

### SongResponseDto (DTO Optimizado para Flutter)

```typescript
{
  id: string;
  title: string;
  duration: number;
  durationFormatted: string; // "3:47"
  fileUrl: string;
  coverArtUrl?: string;
  featured: boolean;
  releaseDate?: Date;
  totalStreams: number;
  totalLikes: number;
  totalShares: number;
  createdAt: Date;
  artist: {
    id: string;
    stageName: string;
    avatarUrl?: string;
  };
  album?: {
    id: string;
    title: string;
    coverArtUrl?: string;
  };
  genre?: {
    id: string;
    name: string;
    colorHex?: string;
  };
}
```

## Flujo de Uso en Flutter

### 1. Cargar Feed del Home

```dart
// Al abrir la app
final response = await dio.get('/api/v1/public/songs/home-feed');
final homeFeed = HomeFeedResponse.fromJson(response.data);

// Mostrar destacadas primero
displayFeaturedSongs(homeFeed.featured);

// Luego mostrar nuevas
displayNewSongs(homeFeed.newSongs);
```

### 2. Cargar Más Canciones (Paginación)

```dart
// Al hacer scroll
int page = 1;
final response = await dio.get(
  '/api/v1/public/songs',
  queryParameters: {
    'page': page++,
    'limit': 20,
  },
);
```

### 3. Filtrar por Destacadas

```dart
final response = await dio.get(
  '/api/v1/public/songs',
  queryParameters: {
    'featured': true,
    'limit': 20,
  },
);
```

### 4. Buscar Canciones

```dart
final response = await dio.get(
  '/api/v1/public/songs',
  queryParameters: {
    'search': 'rock',
    'limit': 20,
  },
);
```

## Migración de Base de Datos

Ejecutar la migración para crear los índices:

```sql
-- Ver archivo: apps/backend/src/database/migrations/add-song-featured-index.sql
```

O ejecutar manualmente:

```bash
docker exec -i vintage-music-postgres psql -U postgres -d vintage_music_db < apps/backend/src/database/migrations/add-song-featured-index.sql
```

## Notas Importantes

1. **Autenticación**: Los endpoints públicos (`/api/v1/public/songs`) NO requieren autenticación
2. **Límites**: El límite máximo de elementos por página es 100
3. **Ordenamiento**: Las canciones destacadas siempre aparecen primero cuando se filtran
4. **Performance**: Los índices mejoran significativamente el rendimiento de consultas
5. **Paginación**: Siempre incluye información de paginación para facilitar la navegación

## Próximos Pasos

1. Implementar caching con Redis para respuestas frecuentes
2. Agregar rate limiting para prevenir abuso
3. Implementar WebSockets para actualizaciones en tiempo real
4. Agregar filtros adicionales (fecha, popularidad, etc.)
