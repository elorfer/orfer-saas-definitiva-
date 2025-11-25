# 🧪 Cómo Probar el Sistema de Subida de Canciones

## 📋 Pre-requisitos

1. **Redis instalado y corriendo**
2. **PostgreSQL con la base de datos configurada**
3. **Node.js y npm instalados**

---

## 🚀 Paso 1: Instalar Dependencias

```bash
cd apps/backend
npm install
```

Esto instalará `@nestjs/bull` y `bull` que son necesarios para las colas.

---

## 🔧 Paso 2: Configurar Redis

### Opción A: Redis Local

```bash
# Windows (con Chocolatey)
choco install redis-64

# O descargar desde: https://github.com/microsoftarchive/redis/releases

# Iniciar Redis
redis-server
```

### Opción B: Redis con Docker

```bash
docker run -d -p 6379:6379 --name redis redis:alpine
```

### Verificar que Redis está corriendo

```bash
# Windows
redis-cli ping
# Debe responder: PONG

# Linux/Mac
redis-cli ping
# Debe responder: PONG
```

---

## 🗄️ Paso 3: Configurar Variables de Entorno

Crea o edita `.env` en `apps/backend/`:

```env
# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Base de datos (ya deberías tener esto)
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=vintage_user
DB_PASSWORD=vintage_password_2024
DB_DATABASE=vintage_music

# App
APP_URL=http://localhost:3000
NODE_ENV=development
```

---

## 📊 Paso 4: Ejecutar Migración de Base de Datos

### Opción A: SQL Manual (Recomendado)

```bash
# Conectarte a PostgreSQL
psql -U vintage_user -d vintage_music

# Ejecutar el SQL
\i src/database/migrations/create-song-uploads-table.sql

# O copiar y pegar el contenido del archivo directamente
```

### Opción B: TypeORM (si tienes migraciones configuradas)

```bash
npm run migration:run
```

### Verificar que la tabla existe

```sql
-- En psql
\dt song_uploads

-- O
SELECT * FROM song_uploads LIMIT 1;
```

---

## ▶️ Paso 5: Iniciar el Servidor

```bash
cd apps/backend
npm run start:dev
```

Deberías ver:
```
[Nest] INFO  Nest application successfully started
```

**⚠️ IMPORTANTE**: Si ves errores de conexión a Redis, verifica que Redis esté corriendo.

---

## 🧪 Paso 6: Probar el Sistema

### Opción 1: Desde el Admin Panel (Más Fácil)

1. **Inicia el Admin Panel** (si no está corriendo):
   ```bash
   cd apps/admin
   npm run dev
   ```

2. **Abre el navegador**: `http://localhost:3002`

3. **Inicia sesión** como admin

4. **Ve a "Gestionar canciones"** → **"Subir canción"**

5. **Sube una canción**:
   - Selecciona archivo de audio
   - (Opcional) Selecciona portada
   - Ingresa título
   - Selecciona artista
   - Click en "Subir canción"

6. **Observa**:
   - La respuesta será **202 Accepted** (antes era 201)
   - Verás un mensaje de "procesando en segundo plano"
   - El estado cambiará a "processing" y luego a "completed"

### Opción 2: Swagger UI (Para pruebas técnicas)

1. **Abre Swagger**: `http://localhost:3000/api/v1/docs`

2. **Autentícate**:
   - POST `/auth/login` con tus credenciales
   - Copia el `access_token`

3. **Autoriza en Swagger**:
   - Click en "Authorize" (🔒)
   - Pega el token: `Bearer {tu-token}`

4. **Prueba el endpoint**:
   - POST `/songs/upload`
   - Click en "Try it out"
   - Sube archivos y completa los campos
   - Click en "Execute"

5. **Verifica la respuesta**:
   ```json
   {
     "uploadId": "upload-1234567890-abc123",
     "status": "processing",
     "jobId": "123",
     "message": "Upload iniciado, procesando en segundo plano",
     "checkStatusUrl": "/api/v1/songs/upload/upload-1234567890-abc123/status"
   }
   ```

6. **Consulta el estado**:
   - GET `/songs/upload/{uploadId}/status`
   - Usa el `uploadId` de la respuesta anterior

### Opción 3: Postman (Para pruebas avanzadas)

1. **Crea una nueva request**:
   - Method: `POST`
   - URL: `http://localhost:3000/api/v1/songs/upload`

2. **Headers**:
   ```
   Authorization: Bearer {tu-token}
   ```

3. **Body**:
   - Selecciona `form-data`
   - Agrega campos:
     - `audio` (File): [selecciona archivo]
     - `cover` (File, opcional): [selecciona imagen]
     - `title` (Text): "Mi Canción de Prueba"
     - `artistId` (Text): "{id-de-un-artista}"
     - `uploadId` (Text, opcional): "test-123" (para idempotencia)

4. **Envía la request**

5. **Verifica respuesta 202**:
   ```json
   {
     "uploadId": "test-123",
     "status": "processing",
     "jobId": "456",
     "message": "Upload iniciado, procesando en segundo plano",
     "checkStatusUrl": "/api/v1/songs/upload/test-123/status"
   }
   ```

6. **Consulta estado**:
   - Nueva request: `GET http://localhost:3000/api/v1/songs/upload/test-123/status`
   - Header: `Authorization: Bearer {tu-token}`
   - Envía y verifica el estado

---

## ✅ Qué Verificar

### 1. **Respuesta Inmediata (202 Accepted)**
   - El endpoint responde rápido (no espera procesamiento)
   - Status code: `202` (no `201`)

### 2. **Idempotencia**
   - Envía el mismo request dos veces con el mismo `uploadId`
   - La segunda vez debe retornar el estado del primero (no crea duplicados)

### 3. **Procesamiento en Background**
   - Revisa los logs del servidor
   - Deberías ver: `🔄 Procesando job...`
   - Luego: `✅ Job completado`

### 4. **Estado en Base de Datos**
   ```sql
   SELECT * FROM song_uploads ORDER BY created_at DESC LIMIT 5;
   ```
   - Deberías ver registros con diferentes estados
   - `status` cambia de `pending` → `processing` → `completed`

### 5. **Canción Creada**
   ```sql
   SELECT * FROM songs ORDER BY created_at DESC LIMIT 5;
   ```
   - Deberías ver la canción creada
   - Con `file_url` y `cover_art_url` correctos

### 6. **Compensación (Si falla)**
   - Si hay un error, verifica logs:
     - `🔄 Iniciando limpieza de archivos (compensación)...`
     - `✅ Limpieza completada`
   - Verifica que `compensation_applied = true` en BD

---

## 🐛 Troubleshooting

### Error: "Cannot connect to Redis"

**Solución:**
```bash
# Verificar que Redis está corriendo
redis-cli ping

# Si no responde PONG, iniciar Redis
redis-server
```

### Error: "Table song_uploads does not exist"

**Solución:**
```bash
# Ejecutar migración SQL manualmente
psql -U vintage_user -d vintage_music -f src/database/migrations/create-song-uploads-table.sql
```

### Upload queda en "processing" indefinidamente

**Solución:**
1. Verifica logs del servidor (debería haber errores)
2. Verifica que Redis está funcionando
3. Verifica que el worker está procesando:
   ```bash
   # En los logs deberías ver:
   # 🔄 Procesando job...
   ```

### Error: "music-metadata no está instalado"

**Solución:**
```bash
cd apps/backend
npm install music-metadata
```

---

## 📊 Monitoreo

### Ver Jobs en Cola (BullMQ)

Puedes usar **Bull Board** para ver los jobs:

```bash
npm install @bull-board/express @bull-board/api
```

O simplemente revisa los logs del servidor para ver el progreso.

### Logs Importantes

Busca en los logs:
- `🚀 INICIANDO PROCESO DE SUBIDA`
- `✅ Job enviado a cola`
- `🔄 Procesando job`
- `✅ Job completado`
- `🎉 Canción creada exitosamente`

---

## 🎯 Pruebas Recomendadas

1. **Subida Normal**: Sube una canción completa
2. **Idempotencia**: Envía el mismo `uploadId` dos veces
3. **Sin Portada**: Sube solo audio (sin portada)
4. **Error Simulado**: Intenta subir con `artistId` inválido (debe limpiar archivos)
5. **Consulta Estado**: Verifica que el endpoint de estado funciona

---

## 📝 Notas

- El procesamiento puede tardar unos segundos (extracción de metadatos)
- Los archivos se guardan en `apps/backend/uploads/`
- Los logs son muy detallados en modo desarrollo
- Redis debe estar corriendo siempre que uses el sistema

---

**¡Listo para probar! 🚀**










