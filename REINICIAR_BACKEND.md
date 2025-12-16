# 🔄 Pasos para Probar el Nuevo Endpoint

## ⚠️ IMPORTANTE: Reiniciar el Backend

El nuevo endpoint `generatePlaylistBatch` fue agregado al código, pero **el backend necesita reiniciarse** para que los cambios surtan efecto.

## 📋 Pasos:

### 1. Detener el Backend (si está corriendo)
- Presiona `Ctrl+C` en la terminal donde está corriendo el backend
- O cierra la terminal

### 2. Reiniciar el Backend
```bash
cd apps/backend
npm run start:dev
# O
yarn start:dev
```

Espera a que veas el mensaje de que el servidor está corriendo (normalmente muestra el puerto 3001)

### 3. Probar el Endpoint

**Opción A: PowerShell**
```powershell
Invoke-RestMethod -Uri "http://localhost:3001/public/songs/playlist/generate?seed=1f4a62b3-e5d9-402e-81d8-a281db16db73&count=4" -Method Get | ConvertTo-Json -Depth 5
```

**Opción B: Navegador**
Abre en tu navegador:
```
http://localhost:3001/public/songs/playlist/generate?seed=1f4a62b3-e5d9-402e-81d8-a281db16db73&count=4
```

**Opción C: Postman**
- Método: GET
- URL: `http://localhost:3001/public/songs/playlist/generate`
- Query Params:
  - `seed`: `1f4a62b3-e5d9-402e-81d8-a281db16db73`
  - `count`: `4`

### 4. Verificar la Respuesta

Deberías recibir algo como:
```json
{
  "songs": [
    {
      "id": "...",
      "title": "Canción 1",
      ...
    },
    ...
  ],
  "count": 4,
  "requested": 4,
  "seed": "1f4a62b3-e5d9-402e-81d8-a281db16db73",
  "processingTime": 1234,
  "algorithm": "spotify-style-batch-v1"
}
```

### 5. Verificar Logs del Backend

En la terminal del backend deberías ver:
```
🚀 [BATCH API] Generando 4 recomendaciones para semilla: 1f4a62b3...
🚀 [BATCH] Generando 4 recomendaciones para semilla: 1f4a62b3...
✅ [BATCH] Recomendación 1/4: ...
✅ [BATCH] Recomendación 2/4: ...
✅ [BATCH] Recomendación 3/4: ...
✅ [BATCH] Recomendación 4/4: ...
🚀 [BATCH] Completado en Xms: 4/4 recomendaciones generadas
✅ [BATCH API] Completado en Xms: 4/4 recomendaciones
```

## ❌ Si Aún No Funciona:

1. **Verifica que el backend esté corriendo:**
   ```powershell
   # Debería responder algo
   Invoke-RestMethod -Uri "http://localhost:3001/public/songs/top?limit=1" -Method Get
   ```

2. **Verifica que el código esté guardado:**
   - Asegúrate de que `public-songs.controller.ts` tenga el método `generatePlaylistBatch`
   - Asegúrate de que `recommendation.service.ts` tenga el método `generatePlaylistBatch`

3. **Revisa los logs del backend:**
   - Busca errores de compilación
   - Busca errores de TypeScript

4. **Verifica el orden de las rutas:**
   - El endpoint `playlist/generate` debe estar **ANTES** de `recommended/:songId` en el controlador















