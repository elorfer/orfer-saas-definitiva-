# 📦 Instalación de Dependencias Opcionales

## 📋 Resumen

Se ha implementado la lógica para extracción de metadatos de audio y compresión de imágenes. Estas funcionalidades funcionan **con o sin** las dependencias instaladas:

- **Sin dependencias:** Funciona con valores por defecto o métodos básicos
- **Con dependencias:** Funciona con funcionalidad completa y optimizada

---

## 🎵 Extracción de Metadatos de Audio

### Estado Actual
- ✅ Lógica implementada en `AudioMetadataService`
- ✅ Funciona sin dependencias (duración = 0)
- ⚠️ Para duración real, instalar `music-metadata`

### Instalación (Opcional pero Recomendado)

```bash
cd apps/backend
npm install music-metadata
```

### Qué Hace
- Extrae duración real del archivo de audio
- Extrae bitrate, codec, sample rate, canales
- Extrae metadatos ID3 (título, artista, álbum) si están disponibles

### Sin Instalación
- La duración será `0` o valor por defecto
- El sistema funcionará pero sin duración correcta

---

## 🖼️ Compresión de Imágenes

### Estado Actual
- ✅ Lógica implementada en `ImageProcessingService`
- ✅ Funciona sin dependencias (imágenes sin comprimir)
- ⚠️ Para compresión real, instalar `sharp`

### Instalación (Opcional pero Recomendado)

```bash
cd apps/backend
npm install sharp
```

### Qué Hace
- Comprime imágenes reduciendo tamaño 60-80%
- Redimensiona imágenes grandes (máx 1200x1200)
- Valida dimensiones (mín 300x300, máx 2000x2000)
- Optimiza calidad manteniendo buena visualización

### Sin Instalación
- Las imágenes se guardan sin comprimir
- No se validan dimensiones
- Mayor uso de espacio y ancho de banda

---

## 📝 Instalación Completa (Recomendado)

```bash
cd apps/backend
npm install music-metadata sharp
```

**Nota:** `sharp` puede requerir compilación nativa. Si hay problemas, consulta la [documentación de sharp](https://sharp.pixelplumbing.com/install).

---

## 🔍 Verificación

### Verificar si están instaladas

```bash
cd apps/backend
npm list music-metadata sharp
```

### Verificar funcionamiento

1. **Metadatos de audio:**
   - Sube una canción
   - Verifica que la duración sea correcta (no 0)
   - Revisa logs del servidor

2. **Compresión de imágenes:**
   - Sube una portada grande (>1MB)
   - Verifica que el archivo guardado sea más pequeño
   - Revisa logs del servidor para ver porcentaje de compresión

---

## ⚠️ Notas Importantes

### Windows
- `sharp` puede requerir herramientas de compilación
- Si falla, usar versión precompilada: `npm install --platform=win32 sharp`

### Linux/Mac
- Generalmente funciona sin problemas
- Puede requerir `libvips` en algunos sistemas

### Docker
- Asegúrate de instalar dependencias en el Dockerfile
- `sharp` necesita librerías del sistema

---

## 🚀 Próximos Pasos

1. **Instalar dependencias** (recomendado)
2. **Probar subida de canción** con archivo real
3. **Verificar duración** en la base de datos
4. **Verificar compresión** de portadas

---

## 📊 Impacto Esperado

### Con Dependencias Instaladas:
- ✅ Duración correcta en todas las canciones
- ✅ Portadas 60-80% más pequeñas
- ✅ Validación de dimensiones
- ✅ Mejor rendimiento general

### Sin Dependencias:
- ⚠️ Duración = 0 (se puede actualizar después)
- ⚠️ Portadas sin comprimir
- ⚠️ Sin validación de dimensiones
- ✅ Sistema funciona normalmente

---

## ✅ Conclusión

El sistema está **listo para usar** con o sin dependencias. Para funcionalidad completa, instala las dependencias opcionales.




