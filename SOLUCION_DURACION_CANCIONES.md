# Solución: Duración de Canciones

## Problema
Las nuevas canciones subidas muestran duración "0:00" en el panel de administración.

## Causa
El servidor backend necesita reiniciarse después de instalar `music-metadata` para que la extracción de metadatos funcione correctamente.

## Solución

### 1. Reiniciar el servidor backend

**IMPORTANTE:** El servidor debe estar corriendo con `music-metadata` instalado.

```bash
# Detén el servidor actual (Ctrl+C en la terminal donde está corriendo)
# Luego reinícialo:
cd apps/backend
npm run start:dev
```

### 2. Verificar que music-metadata está instalado

```bash
cd apps/backend
npm list music-metadata
```

Debería mostrar: `music-metadata@11.10.0` o similar.

### 3. Subir una nueva canción

Después de reiniciar el servidor:
1. Ve al panel de administración
2. Sube una nueva canción
3. Revisa los logs del backend - deberías ver:
   ```
   ✅ music-metadata disponible - usando extracción completa
   🔄 Analizando archivo con music-metadata...
   ✅ Metadatos extraídos con music-metadata: duración=XXXs
   ⏱️ Duración final a guardar: XXXs (X:XX)
   ```

### 4. Si una canción ya subida muestra "0:00"

Puedes actualizarla manualmente usando el endpoint:

```bash
POST /api/v1/songs/:id/update-duration
```

O ejecutar el script de actualización masiva:

```bash
cd apps/backend
npm run update-durations
```

## Verificación

Después de reiniciar y subir una nueva canción:
- ✅ La duración debe mostrarse correctamente en el panel
- ✅ Los logs del backend deben mostrar la extracción exitosa
- ✅ La duración debe guardarse en la base de datos

## Notas

- Las canciones subidas ANTES de instalar `music-metadata` tendrán duración 0 hasta que se actualicen
- El script `update-durations` actualiza todas las canciones con duración = 0
- Las nuevas canciones subidas DESPUÉS de reiniciar el servidor deberían tener duración correcta automáticamente


