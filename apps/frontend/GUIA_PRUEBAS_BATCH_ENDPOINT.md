# 🧪 Guía de Pruebas: Nuevo Endpoint de Batching

## ✅ Verificación rápida

### 1. **Probar el Endpoint Directamente (Backend)**

Abre tu terminal y prueba el endpoint con curl o Postman:

#### Opción A: Con cURL (Terminal)

```bash
# Probar con una canción semilla (reemplaza SONG_ID con un ID real)
curl "http://localhost:3001/public/songs/playlist/generate?seed=TU_SONG_ID&count=4"

# Ejemplo con parámetros adicionales
curl "http://localhost:3001/public/songs/playlist/generate?seed=TU_SONG_ID&count=4&userId=TU_USER_ID"

# Con excludeIds
curl "http://localhost:3001/public/songs/playlist/generate?seed=TU_SONG_ID&count=4&excludeIds=ID1,ID2,ID3"
```

#### Opción B: Con Postman/Browser

```
GET http://localhost:3001/public/songs/playlist/generate
Query Params:
  - seed: TU_SONG_ID (requerido)
  - count: 4 (opcional, default: 4, max: 20)
  - userId: TU_USER_ID (opcional)
  - genres: reggaeton,latino (opcional)
  - excludeIds: ID1,ID2,ID3 (opcional, separados por coma)
```

**Respuesta esperada:**
```json
{
  "songs": [
    {
      "id": "...",
      "title": "Canción 1",
      ...
    },
    {
      "id": "...",
      "title": "Canción 2",
      ...
    },
    ...
  ],
  "count": 4,
  "requested": 4,
  "seed": "TU_SONG_ID",
  "processingTime": 1234,
  "algorithm": "spotify-style-batch-v1"
}
```

---

### 2. **Probar desde la App Flutter**

#### Paso 1: Verificar que el Backend está corriendo

```bash
cd apps/backend
npm run start:dev
# O
yarn start:dev
```

Verifica que el servidor esté en `http://localhost:3001`

#### Paso 2: Ejecutar la App Flutter

```bash
cd apps/frontend
flutter run
```

#### Paso 3: Monitorear los Logs

Busca estos logs en la consola para confirmar que está usando el nuevo endpoint:

**✅ Logs Esperados (NUEVO endpoint):**
```
🚀 [IntelligentFeatured] Fase 1: solicitando 4 recomendaciones usando batch endpoint para canción 1f4a62b3...
🚀 [SpotifyRec Batch] Respuesta recibida: 4/4 canciones
✅ [SpotifyRec Batch] 4 canciones parseadas exitosamente
✅ [IntelligentFeatured] Fase 1: 4/4 recomendaciones recibidas del batch
```

**❌ Logs Antiguos (si aún aparece, algo está mal):**
```
📡 [IntelligentFeatured] Fase 1 llamada 1/4: offset=0
📡 [IntelligentFeatured] Fase 1 llamada 2/4: offset=1
⏳ [IntelligentFeatured] Fase 1: esperando 4 respuestas en paralelo...
```

---

### 3. **Verificar en los Logs del Backend**

En la terminal del backend, deberías ver:

**✅ Logs Esperados:**
```
🚀 [BATCH] Generando 4 recomendaciones para semilla: 1f4a62b3...
👤 [BATCH] Usuario: anónimo
🚫 [BATCH] Excluyendo 0 IDs
✅ [BATCH] Recomendación 1/4: CANCIÓN 1 (ID: 94351183...)
✅ [BATCH] Recomendación 2/4: CANCIÓN 2 (ID: 0a653dc1...)
✅ [BATCH] Recomendación 3/4: CANCIÓN 3 (ID: b97af9ae...)
✅ [BATCH] Recomendación 4/4: CANCIÓN 4 (ID: 8e94791a...)
🚀 [BATCH] Completado en 1234ms: 4/4 recomendaciones generadas
```

**Y en el controlador:**
```
🚀 [BATCH API] Generando 4 recomendaciones para semilla: 1f4a62b3...
✅ [BATCH API] Completado en 1234ms: 4/4 recomendaciones
```

---

### 4. **Pruebas Funcionales**

#### Test 1: Reproducir una canción en modo algoritmo
1. Abre la app
2. Reproduce una canción
3. Activa el modo algoritmo (si está disponible)
4. Verifica que se carguen recomendaciones sin problemas

#### Test 2: Verificar que no hay duplicados
1. En los logs, verifica que cada recomendación tenga un ID único
2. Confirma que las canciones recomendadas no se repiten

#### Test 3: Verificar rendimiento
1. Compara el tiempo de respuesta anterior vs. el nuevo
2. Antes: 4 requests paralelas (cada una ~1-2s) = ~2-4s total
3. Ahora: 1 request batch = ~1-3s total
4. Debería ser **más rápido** o similar, pero con menos requests

---

### 5. **Pruebas de Errores**

#### Test de Error 1: Semilla inválida
```bash
curl "http://localhost:3001/public/songs/playlist/generate?seed=INVALID_ID&count=4"
```
**Esperado:** Respuesta con `songs: []` y `count: 0`

#### Test de Error 2: Count muy alto
```bash
curl "http://localhost:3001/public/songs/playlist/generate?seed=TU_SONG_ID&count=100"
```
**Esperado:** Se limita a 20 (máximo permitido)

#### Test de Error 3: Sin semilla
```bash
curl "http://localhost:3001/public/songs/playlist/generate?count=4"
```
**Esperado:** Error 400 (Bad Request)

---

### 6. **Comparar Antes vs. Ahora**

#### Antes (Legacy):
- **Requests:** 4 llamadas HTTP paralelas
- **Tiempo:** ~2-4 segundos
- **Complejidad Frontend:** Alta (manejo de Future.wait, offsets, etc.)
- **Logs:** Muchos logs de "Fase 1 llamada X/Y"

#### Ahora (Optimizado):
- **Requests:** 1 llamada HTTP
- **Tiempo:** ~1-3 segundos (similar o mejor)
- **Complejidad Frontend:** Baja (solo 1 llamada)
- **Logs:** 1 log de "batch endpoint"

---

## 🔍 Debugging

### Si no funciona:

1. **Verifica que el backend tenga el nuevo método:**
   ```bash
   # Buscar en el código
   grep -r "generatePlaylistBatch" apps/backend/src/
   ```

2. **Verifica que el endpoint esté registrado:**
   ```bash
   # El endpoint debería estar en public-songs.controller.ts
   grep -r "playlist/generate" apps/backend/src/
   ```

3. **Verifica que Flutter tenga el nuevo método:**
   ```bash
   # Buscar en el código
   grep -r "generatePlaylistBatch" apps/frontend/lib/
   ```

4. **Revisa los logs del backend:**
   - Busca errores relacionados con `BATCH` o `generatePlaylistBatch`
   - Verifica que el endpoint esté accesible

5. **Revisa los logs de Flutter:**
   - Busca errores relacionados con `batch endpoint` o `playlist/generate`
   - Verifica que la URL esté correcta

---

## ✅ Checklist de Verificación

- [ ] Backend corriendo en `http://localhost:3001`
- [ ] Endpoint `/public/songs/playlist/generate` responde correctamente con curl
- [ ] App Flutter ejecutándose
- [ ] Logs muestran "batch endpoint" en lugar de "llamadas en paralelo"
- [ ] Backend muestra logs `[BATCH]` y `[BATCH API]`
- [ ] Las recomendaciones se cargan correctamente
- [ ] No hay errores en la consola
- [ ] Performance es igual o mejor que antes

---

## 🎉 ¡Listo!

Si todos los checks están ✅, entonces la implementación está funcionando correctamente y has migrado exitosamente a la arquitectura moderna de batching en el backend.

