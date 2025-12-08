# 🎧 Implementación del Sistema de Streams

## ✅ Archivos Creados

1. **Entidades**
   - `apps/backend/src/common/entities/stream.entity.ts`
   - `apps/backend/src/common/entities/user-listening-session.entity.ts`

2. **Módulo Streams**
   - `apps/backend/src/modules/streams/streams.service.ts`
   - `apps/backend/src/modules/streams/streams.controller.ts`
   - `apps/backend/src/modules/streams/streams.module.ts`
   - `apps/backend/src/modules/streams/dto/track-progress.dto.ts`

3. **Migración**
   - `apps/backend/src/database/migrations/create-streams-system.sql`

## 🔧 Pasos para Integrar

### 1. Instalar dependencias

```bash
cd apps/backend
npm install ioredis
npm install --save-dev @types/ioredis
```

### 2. Ejecutar migración SQL

```bash
psql -U your_user -d your_database -f src/database/migrations/create-streams-system.sql
```

O usar tu herramienta de migración preferida.

### 3. Registrar módulo en app.module.ts

```typescript
import { StreamsModule } from './modules/streams/streams.module';

@Module({
  imports: [
    // ... otros módulos
    StreamsModule,
  ],
})
export class AppModule {}
```

### 4. Agregar entidades a TypeORM

En `apps/backend/src/database/entities.ts` o donde registres entidades:

```typescript
import { Stream } from '../common/entities/stream.entity';
import { UserListeningSession } from '../common/entities/user-listening-session.entity';

export const entities = [
  // ... otras entidades
  Stream,
  UserListeningSession,
];
```

### 5. Configurar Redis

Asegúrate de tener Redis corriendo:

```bash
docker run -d -p 6379:6379 redis:alpine
```

O instalar localmente:
```bash
# Ubuntu/Debian
sudo apt install redis-server

# macOS
brew install redis
```

### 6. Variables de entorno

Agregar a `.env`:

```env
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
```

## 🧪 Testing

### Endpoint de prueba

```bash
# 1. Login y obtener token
TOKEN="your-jwt-token"

# 2. Enviar progreso < 30s (no debe registrar)
curl -X POST http://localhost:3001/api/v1/streams/track-progress \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "songId": "song-uuid",
    "progressMs": 15000,
    "durationMs": 210000,
    "volume": 0.8,
    "isForeground": true
  }'

# Respuesta esperada:
# {
#   "shouldRegisterStream": false,
#   "streamRegistered": false
# }

# 3. Enviar progreso ≥ 30s (debe registrar)
curl -X POST http://localhost:3001/api/v1/streams/track-progress \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "songId": "song-uuid",
    "progressMs": 35000,
    "durationMs": 210000,
    "volume": 0.8,
    "isForeground": true
  }'

# Respuesta esperada:
# {
#   "shouldRegisterStream": true,
#   "streamRegistered": true,
#   "message": "Stream registrado"
# }

# 4. Intentar duplicado inmediato (rate limit)
curl -X POST http://localhost:3001/api/v1/streams/track-progress \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "songId": "song-uuid",
    "progressMs": 45000,
    "durationMs": 210000,
    "volume": 0.8,
    "isForeground": true
  }'

# Respuesta esperada:
# {
#   "shouldRegisterStream": false,
#   "streamRegistered": false,
#   "message": "Rate limit alcanzado"
# }
```

## 📊 Verificar en Base de Datos

```sql
-- Ver streams registrados
SELECT 
  s.id,
  u.email as user_email,
  so.title as song_title,
  s.duration_listened,
  s.created_at
FROM streams s
JOIN users u ON s.user_id = u.id
JOIN songs so ON s.song_id = so.id
ORDER BY s.created_at DESC
LIMIT 10;

-- Ver sesiones activas
SELECT 
  uls.user_id,
  uls.song_id,
  uls.max_progress_ms,
  uls.is_stream_validated,
  uls.started_at
FROM user_listening_sessions uls
WHERE uls.created_at > NOW() - INTERVAL '1 hour'
ORDER BY uls.started_at DESC;

-- Verificar contadores
SELECT 
  so.title,
  so.total_streams as song_streams,
  a.stage_name as artist,
  a.total_streams as artist_streams
FROM songs so
JOIN artists a ON so.artist_id = a.id
WHERE so.total_streams > 0
ORDER BY so.total_streams DESC
LIMIT 10;
```

## 🔍 Validaciones Implementadas

✅ 30 segundos mínimos de escucha  
✅ Rate limiting (1 stream/30s por usuario/canción)  
✅ Validación de volumen (ignora si = 0)  
✅ Validación de app en foreground  
✅ Prevención de saltos sospechosos de progreso  
✅ Transacciones atómicas para contadores  
✅ Prevención de duplicados por sesión  

## 🚨 Troubleshooting

### Redis no conecta
- Verificar que Redis esté corriendo: `redis-cli ping`
- Revisar variables de entorno
- Verificar firewall/puertos

### Streams no se registran
- Verificar que progreso ≥ 30000ms
- Revisar logs del servicio
- Verificar rate limit en Redis: `redis-cli GET stream:rate_limit:USER_ID:SONG_ID`

### Contadores no incrementan
- Verificar transacciones en logs
- Revisar que `totalStreams` sea tipo `bigint` o `integer` en DB
- Verificar relaciones Song-Artist

## 📈 Próximos Pasos (Opcionales)

- [ ] Dashboard de analytics
- [ ] Exportar stats a tabla `streaming_stats`
- [ ] Webhook para notificaciones de streams
- [ ] Batch processing para limpieza automática
- [ ] Métricas de engagement (tiempo promedio, etc.)






