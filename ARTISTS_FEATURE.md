## Artistas - Arquitectura y Guía de Uso

### Esquema de BD
- Tabla `artists` (existente, extendida):
  - `id` UUID PK
  - `name` VARCHAR(150)
  - `profile_photo_url` TEXT
  - `cover_photo_url` TEXT
  - `nationality_code` CHAR(2) ISO-3166
  - `biography` TEXT
  - `featured` BOOLEAN DEFAULT false
  - `user_id` UUID (relación opcional con `users`)
  - `stage_name`, `bio`, métricas legacy (compatibilidad)
  - `created_at`, `updated_at`

Migración SQL: `apps/backend/src/database/migrations/alter-artists-add-new-columns.sql`

### Endpoints Backend
- POST `/api/v1/artists` (multipart/form-data)
  - Campos: `name` (req), `nationalityCode`, `biography`, `featured`, `userId`
  - Archivos: `profile` (imagen), `cover` (imagen)
  - Respuesta 201: objeto `Artist`

- PUT `/api/v1/artists/:id` (multipart/form-data)
  - Igual que POST, todos opcionales
  - Respuesta 200: objeto `Artist`

- GET `/api/v1/artists`
  - Query: `page`, `limit`
  - Respuesta 200: `{ artists, total }`

- GET `/api/v1/artists/featured`
  - Query: `limit`
  - Respuesta 200: `Artist[]`

- PUT `/api/v1/artists/:id/feature`
  - Body: `{ featured: boolean }`
  - Respuesta 200: `Artist`

### Subida y procesamiento de imágenes
- Reutiliza el servicio de almacenamiento local (`CoversStorageService`) preparado para S3.
- Validación de tipo: `jpeg`, `jpg`, `png`, `webp`, `gif`
- Tamaño máximo: 10MB (configurable)
- Optimización a WebP: configurable a futuro (hook en `CoversStorageService`)
- URLs públicas servidas en `/uploads/covers/...`

### Selector de nacionalidad con banderas
- UI: dropdown con nombre de país + bandera (emoji o asset SVG).
- Persistencia: se guarda el código ISO-3166 de 2 letras (`nationality_code`).
- Visualización: mostrar bandera (emoji o SVG) + nombre en:
  - Lista de artistas
  - Detalle de artista
  - Formularios de crear/editar

### Artistas destacados
- Campo booleano `featured`
- Endpoints:
  - GET `/artists/featured` para el home y secciones destacadas (móvil y admin)
  - PUT `/artists/:id/feature` para alternar estado

### Ejemplos de Requests
Crear (multipart):
```
POST /api/v1/artists
Content-Type: multipart/form-data
Fields:
  name=Shakira
  nationalityCode=CO
  biography=Artista colombiana...
  featured=true
  profile=<archivo .png/.jpg/.webp>
  cover=<archivo .png/.jpg/.webp>
```

Editar (multipart):
```
PUT /api/v1/artists/:id
Content-Type: multipart/form-data
Fields:
  name=Shakira
  biography=Actualización bio...
  profile=<nuevo archivo opcional>
  cover=<nuevo archivo opcional>
```

Marcar destacado:
```
PUT /api/v1/artists/:id/feature
Body: { "featured": true }
```

### Respuestas JSON (ejemplo)
```
{
  "id": "uuid",
  "name": "Shakira",
  "profilePhotoUrl": "http://localhost:3000/uploads/covers/uuid.webp",
  "coverPhotoUrl": "http://localhost:3000/uploads/covers/uuid.webp",
  "nationalityCode": "CO",
  "biography": "Artista colombiana...",
  "featured": true,
  "createdAt": "2025-11-16T12:00:00.000Z",
  "updatedAt": "2025-11-16T12:00:00.000Z"
}
```

### Notas para la App Móvil
- Consumir `/artists/featured` para la sección de destacados.
- Los objetos incluyen `profilePhotoUrl` y `coverPhotoUrl` listos para mostrar.
- Usar `nationalityCode` para mostrar bandera localmente (tabla ISO-3166).

