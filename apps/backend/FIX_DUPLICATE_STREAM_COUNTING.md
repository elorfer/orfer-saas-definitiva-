# 🐛 FIX: Conteo Duplicado de Reproducciones

## Problema Identificado

Las reproducciones se estaban contando **múltiples veces** por cada canción reproducida, causando que el contador de "REPRODUCCIONES" en el dashboard se incrementara más rápido de lo esperado.

### Evidencia del Problema

**Logs del servidor:**
```
[getGlobalStats] totalStreams: 6
[getGlobalStats] totalStreams: 7  (+1)
[getGlobalStats] totalStreams: 8  (+1)
[getGlobalStats] totalStreams: 11 (+3) ⚠️
[getGlobalStats] totalStreams: 12 (+1)
[getGlobalStats] totalStreams: 13 (+1)
```

Observamos que en una sola reproducción, el contador se incrementó **+3**, cuando debería incrementarse solo **+1** por reproducción válida (30+ segundos).

## Causa Raíz

Existían **MÚLTIPLES lugares incrementando `totalStreams`**:

### 1. ✅ **`StreamsService.registerStream()`** (CORRECTO)
- **Ubicación**: `apps/backend/src/modules/streams/streams.service.ts:261`
- **Validaciones**:
  - ✅ Mínimo 30 segundos escuchados
  - ✅ Anti-fraude (volumen, foreground)
  - ✅ Progreso natural (no saltos)
  - ✅ Rate limiting (30s entre streams)
  - ✅ Sesiones de usuario
- **Endpoint**: `POST /streams/track-progress`
- **Estado**: **MANTENER** - Este es el sistema correcto

### 2. ❌ **`StreamingService.getStreamUrl()`** (INCORRECTO - REMOVIDO)
- **Ubicación**: `apps/backend/src/modules/streaming/streaming.service.ts:31`
- **Validaciones**:
  - ❌ NINGUNA validación
  - ❌ Se ejecuta cada vez que se solicita la URL
  - ❌ No verifica tiempo mínimo
  - ❌ No tiene rate limiting
- **Endpoint**: `GET /streaming/song/:id/stream`
- **Estado**: **REMOVIDO** ✅

### 3. ⚠️ **`SongsService.incrementStreams()`** (MANUAL)
- **Ubicación**: `apps/backend/src/modules/songs/songs.service.ts:153`
- **Validaciones**: ❌ NINGUNA
- **Endpoint**: `PATCH /songs/:id/increment-streams`
- **Uso**: Solo para uso manual/admin
- **Estado**: **MANTENER** - Útil para casos especiales

## ¿Cómo Ocurría el Problema?

### Flujo Anterior (Incorrecto):

```
Usuario reproduce una canción
    ↓
1. Flutter solicita URL → GET /streaming/song/:id/stream
   → ❌ totalStreams +1 (SIN VALIDACIÓN)
    ↓
2. Flutter inicia reproducción
    ↓
3. Flutter envía progreso cada 10s → POST /streams/track-progress
    ↓
4. Después de 30s → StreamsService valida
   → ✅ totalStreams +1 (CON VALIDACIÓN)
    ↓
RESULTADO: totalStreams +2 por una sola reproducción ❌
```

### Flujo Actual (Correcto):

```
Usuario reproduce una canción
    ↓
1. Flutter solicita URL → GET /streaming/song/:id/stream
   → ℹ️ Solo devuelve URL (NO incrementa)
    ↓
2. Flutter inicia reproducción
    ↓
3. Flutter envía progreso cada 10s → POST /streams/track-progress
    ↓
4. Después de 30s → StreamsService valida
   → ✅ totalStreams +1 (CON VALIDACIÓN)
    ↓
RESULTADO: totalStreams +1 por una sola reproducción ✅
```

## Solución Implementada

### Cambios en `streaming.service.ts`

**Antes:**
```typescript
async getStreamUrl(songId: string, userId: string) {
  const song = await this.songRepository.findOne({ where: { id: songId } });
  
  if (!song) {
    throw new NotFoundException('Canción no encontrada');
  }

  // ❌ PROBLEMA: Incrementa sin validación
  await this.recordPlay(songId, userId);
  await this.songRepository.increment({ id: songId }, 'totalStreams', 1);

  return {
    streamUrl: song.fileUrl,
    hlsUrl: song.fileUrl.replace(/\.[^/.]+$/, '.m3u8'),
  };
}
```

**Después:**
```typescript
async getStreamUrl(songId: string, userId: string) {
  const song = await this.songRepository.findOne({ where: { id: songId } });
  
  if (!song) {
    throw new NotFoundException('Canción no encontrada');
  }

  // ✅ SOLUCIÓN: No incrementar aquí
  // El conteo correcto se hace en StreamsService.trackProgress()
  // después de validar que se escucharon al menos 30 segundos
  
  return {
    streamUrl: song.fileUrl,
    hlsUrl: song.fileUrl.replace(/\.[^/.]+$/, '.m3u8'),
  };
}
```

## Verificación de la Solución

### Antes del Fix:
- Reproducción de 1 canción → `totalStreams` incrementa +2 o +3
- Dashboard muestra conteos inflados
- Estadísticas no confiables

### Después del Fix:
- Reproducción de 1 canción → `totalStreams` incrementa +1 (solo si escucha 30+ seg)
- Dashboard muestra conteos precisos
- Estadísticas confiables y anti-fraude

## Sistema de Tracking Profesional

El sistema correcto de tracking en `StreamsService` incluye:

### 🛡️ Validaciones Anti-Fraude
```typescript
// 1. Mínimo 30 segundos escuchados
if (maxProgressMs < MIN_STREAM_DURATION_MS) return false;

// 2. No contar si volumen = 0 y app en background
if (!isForeground && volume === 0) return false;

// 3. Progreso natural (no saltos sospechosos)
if (maxProgressMs > maxAllowedProgress) return false;
```

### ⏱️ Rate Limiting
```typescript
// Solo 1 stream cada 30 segundos por usuario/canción
const rateLimitKey = `stream:rate_limit:${userId}:${songId}`;
await redis.setex(rateLimitKey, 30, '1');
```

### 📊 Sesiones de Usuario
```typescript
// Tracking de progreso real del usuario
// Detecta replays y nuevas reproducciones
if (progressMs < 10000 && session.isStreamValidated) {
  // Nueva reproducción - resetear sesión
}
```

## Impacto del Fix

### ✅ Beneficios:
1. **Conteos precisos**: Solo se cuenta 1 reproducción por escucha válida
2. **Anti-fraude**: Validaciones robustas
3. **Dashboard confiable**: Estadísticas reflejan uso real
4. **Rate limiting**: Previene spam de streams

### ⚠️ Consideraciones:
- Los contadores actuales pueden estar inflados debido al bug anterior
- Recomendado: Usar la función "Reiniciar Estadísticas" para comenzar con datos limpios
- Las nuevas reproducciones se contarán correctamente

## Recomendaciones

### Para Desarrollo:
✅ Reinicia las estadísticas para tener datos limpios:
```bash
# Usar el botón en el dashboard admin
Dashboard → Reiniciar Estadísticas
```

### Para Producción:
⚠️ Si ya hay datos en producción:
1. **Opción 1**: Mantener datos actuales (inflados) como baseline
2. **Opción 2**: Reiniciar estadísticas y comenzar de cero
3. **Opción 3**: Crear script para ajustar contadores dividiendo por factor estimado

## Testing

Para verificar que el fix funciona:

```bash
# 1. Reiniciar estadísticas
POST /api/v1/analytics/reset-stats

# 2. Reproducir 1 canción completa (30+ seg)
GET /api/v1/streaming/song/{id}/stream
POST /api/v1/streams/track-progress (múltiples veces)

# 3. Verificar contador
GET /api/v1/analytics/global
# Debería mostrar totalStreams: 1

# 4. Reproducir la MISMA canción nuevamente
# Debería incrementar a totalStreams: 2
```

---

**Fecha del Fix**: 2026-01-20  
**Archivos Modificados**:
- `apps/backend/src/modules/streaming/streaming.service.ts`

**Relacionado**:
- Sistema de tracking: `apps/backend/src/modules/streams/streams.service.ts`
- Documentación de reset: `apps/admin/REINICIAR_ESTADISTICAS.md`
