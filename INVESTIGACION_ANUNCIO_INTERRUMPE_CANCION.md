# 🔍 INVESTIGACIÓN: Anuncio Interrumpe Canción al Intentar Reproducir

## 📋 RESUMEN DEL PROBLEMA

Cuando un usuario intenta reproducir una canción justo después de que termina otra canción, el anuncio que se está insertando interrumpe la reproducción de la nueva canción.

## 🔎 ANÁLISIS DEL FLUJO ACTUAL

### Flujo Problemático:

1. **Termina una canción** → Se ejecuta `_handleSongCompletion()` (línea 2751)
   - Pausa el reproductor (línea 2770)
   - Llama a `_checkAndInsertAd()` para insertar anuncio (línea 2805)

2. **Usuario presiona play en una nueva canción** → Se ejecuta `playFromCard()` o `togglePlayPause()`
   - Intenta reproducir la nueva canción (línea 4947 en `playFromCard`)

3. **Mientras tanto, `AdInsertionManager.insertAd()` está ejecutándose**:
   - Hace `seek` al anuncio (línea 99 de `ad_insertion_manager.dart`)
   - Esto interrumpe la reproducción de la nueva canción

### Código Problemático:

#### En `playback_notifier.dart` - `_handleSongCompletion()`:
```dart
// Línea 2767-2794
final wasPlaying = service.player.playing;
if (wasPlaying) {
  await service.pause();
  // ... limpia búfer ...
}

// Línea 2799-2810
if (!state.isPlayingAd) {
  _isHandlingAdInsertion = true;
  try {
    await _checkAndInsertAd(); // ⚠️ Esto puede tomar tiempo
  } finally {
    _isHandlingAdInsertion = false;
  }
}
```

#### En `ad_insertion_manager.dart` - `insertAd()`:
```dart
// Línea 93-99
if (player.playing) {
  await player.pause();
  await Future.delayed(const Duration(milliseconds: 50));
}

await player.seek(Duration.zero, index: targetIndex); // ⚠️ Interrumpe cualquier reproducción
```

#### En `playback_notifier.dart` - `playFromCard()`:
```dart
// Línea 4947
await service.play(); // ⚠️ No verifica si hay anuncio siendo insertado
```

## 🐛 CAUSA RAÍZ

**El problema es una condición de carrera (race condition):**

1. `_handleSongCompletion()` inicia la inserción del anuncio de forma asíncrona
2. El usuario puede presionar play antes de que el anuncio se inserte completamente
3. `playFromCard()` o `togglePlayPause()` intenta reproducir sin verificar si hay un anuncio siendo insertado
4. `AdInsertionManager.insertAd()` hace `seek` al anuncio, interrumpiendo la reproducción de la nueva canción

## ✅ SOLUCIÓN PROPUESTA

### Opción 1: Verificar y cancelar inserción de anuncio antes de reproducir (RECOMENDADA)

Agregar verificación en `playFromCard()` y `togglePlayPause()` para cancelar la inserción del anuncio si el usuario está intentando reproducir una canción:

```dart
// En playFromCard() - después de línea 4887
// 🚨 PROTECCIÓN: Si hay un anuncio siendo insertado, cancelar la inserción
if (_isInsertingAd || _isHandlingAdInsertion) {
  AppLogger.info('[PlaybackNotifier] 🛑 Cancelando inserción de anuncio porque usuario quiere reproducir canción');
  _isInsertingAd = false;
  _isHandlingAdInsertion = false;
  
  // Limpiar estado del anuncio
  if (state.isPlayingAd || state.currentAd != null) {
    state = state.copyWith(
      isPlayingAd: false,
      clearCurrentAd: true,
    );
  }
}
```

### Opción 2: Verificar si hay reproducción activa antes de hacer seek al anuncio

Modificar `AdInsertionManager.insertAd()` para verificar si el usuario está intentando reproducir antes de hacer seek:

```dart
// En ad_insertion_manager.dart - antes de línea 99
// ✅ PROTECCIÓN: Verificar si el usuario está intentando reproducir una canción
// Si hay una canción reproduciéndose que no es la que terminó, no hacer seek al anuncio
final sequenceStateBeforeSeek = player.sequenceState;
final sourceBeforeSeek = sequenceStateBeforeSeek.currentSource;
final isSongPlaying = sourceBeforeSeek?.tag is Song;

if (isSongPlaying) {
  AppLogger.info('[AdInsertionManager] ⚠️ Usuario está reproduciendo una canción, omitiendo seek al anuncio');
  // Remover el anuncio de la cola si ya se insertó
  // O simplemente retornar sin hacer seek
  return true; // Anuncio insertado pero no reproducido
}
```

### Opción 3: Esperar a que termine la inserción antes de reproducir

Modificar `playFromCard()` para esperar a que termine la inserción del anuncio:

```dart
// En playFromCard() - después de línea 4887
// 🚨 PROTECCIÓN: Esperar a que termine la inserción del anuncio si está en curso
if (_isInsertingAd || _isHandlingAdInsertion) {
  AppLogger.info('[PlaybackNotifier] ⏳ Esperando a que termine la inserción del anuncio...');
  int attempts = 0;
  while ((_isInsertingAd || _isHandlingAdInsertion) && attempts < 20) {
    await Future.delayed(const Duration(milliseconds: 50));
    attempts++;
  }
  if (attempts >= 20) {
    AppLogger.warning('[PlaybackNotifier] ⚠️ Timeout esperando inserción de anuncio, cancelando...');
    _isInsertingAd = false;
    _isHandlingAdInsertion = false;
  }
}
```

## 🎯 RECOMENDACIÓN

**Implementar Opción 1** porque:
- Es la más directa y eficiente
- Cancela la inserción del anuncio inmediatamente cuando el usuario quiere reproducir
- No introduce delays innecesarios
- Respeta la intención del usuario de reproducir una canción

## ✅ SOLUCIÓN IMPLEMENTADA (ACTUALIZADA)

Se implementaron **DOS soluciones complementarias**:

### Solución 1: Cancelación de Inserción de Anuncio (Ya implementada)
### Solución 2: Pausa Preventiva y Reemplazo de Cola (NUEVA - Solución Definitiva)

### Cambios Realizados:

1. **Modificado `playFromCard()`** en `playback_notifier.dart` (línea ~4887):
   - ✅ Agregada verificación y cancelación de inserción de anuncio antes de reproducir
   - ✅ Limpieza del estado del anuncio para evitar que se muestre en la UI
   - ✅ Verificación de anuncios en la cola

2. **Modificado `togglePlayPause()`** en `playback_notifier.dart` (línea ~3573):
   - ✅ Agregada verificación similar para cancelar inserción de anuncio
   - ✅ Limpieza del estado del anuncio antes de hacer play/pause

3. **Modificado `AdInsertionManager.insertAd()`** en `ad_insertion_manager.dart` (línea ~90):
   - ✅ Agregada verificación antes de hacer seek al anuncio
   - ✅ Si detecta que el usuario está reproduciendo una nueva canción, omite el seek al anuncio
   - ✅ El anuncio se inserta en la cola pero no interrumpe la reproducción

### Código Implementado:

#### En `playFromCard()`:
```dart
// 🚨 PROTECCIÓN CRÍTICA: Si hay un anuncio siendo insertado, cancelar la inserción
if (_isInsertingAd || _isHandlingAdInsertion) {
  AppLogger.info('[PlaybackNotifier] 🛑 Cancelando inserción de anuncio porque usuario quiere reproducir canción');
  _isInsertingAd = false;
  _isHandlingAdInsertion = false;
  
  // Limpiar estado del anuncio
  if (state.isPlayingAd || state.currentAd != null) {
    state = state.copyWith(
      isPlayingAd: false,
      clearCurrentAd: true,
    );
  }
}
```

#### En `AdInsertionManager.insertAd()`:
```dart
// 🚨 PROTECCIÓN CRÍTICA: Verificar si hay una canción reproduciéndose antes de hacer seek
final sequenceStateBeforeSeek = player.sequenceState;
final sourceBeforeSeek = sequenceStateBeforeSeek.currentSource;
final isSongPlaying = sourceBeforeSeek?.tag is Song;
final currentIndexBeforeSeek = sequenceStateBeforeSeek.currentIndex;

if (isSongPlaying && currentIndexBeforeSeek != currentIndexBeforeInsert) {
  AppLogger.warning('[AdInsertionManager] ⚠️ Usuario está reproduciendo una nueva canción, omitiendo seek al anuncio');
  return true; // Anuncio insertado pero no reproducido
}
```

## 🧪 PRUEBAS SUGERIDAS

1. ✅ Reproducir una canción y cuando termine, inmediatamente presionar play en otra canción
2. ✅ Verificar que la nueva canción se reproduce sin interrupción del anuncio
3. ✅ Verificar que el anuncio no se muestra en la UI cuando el usuario está reproduciendo una canción
4. ✅ Verificar que el anuncio se inserta correctamente cuando el usuario no está reproduciendo activamente

## 🛑 SOLUCIÓN DEFINITIVA: PAUSA PREVENTIVA Y REEMPLAZO DE COLA

### Problema Identificado (Inversión de Cola):

El reproductor nativo (ExoPlayer/just_audio) es más rápido avanzando a la siguiente canción que el código insertando el anuncio. Esto causa que:

1. Canción A termina
2. Reproductor nativo salta automáticamente al Índice 1 (Canción B) **ANTES** de que el código pueda insertar el anuncio
3. Para cuando el anuncio está listo, el reproductor ya está reproduciendo la Canción B

### Implementación de Pausa Preventiva:

#### 1. Detección Temprana (200ms antes del final)

Modificado `_checkAndPrepareNextSongTransition()` para detectar cuando quedan 200ms antes del final:

```dart
// 🛑 PAUSA PREVENTIVA: Detectar 200ms antes del final para bloquear avance automático
if (remainingTime.inMilliseconds <= 200 && 
    remainingTime.inMilliseconds > 0 &&
    !state.isPlayingAd &&
    !_isHandlingAdInsertion &&
    !_isInsertingAd) {
  
  // 🚨 BLOQUEO PREVENTIVO: Pausar ANTES de que el reproductor salte automáticamente
  _handlePreventiveAdInsertion();
  return; // No continuar con preparación normal
}
```

#### 2. Método `_handlePreventiveAdInsertion()`

Nuevo método que:
- ✅ Pausa el reproductor inmediatamente (bloquea avance automático)
- ✅ Limpia el búfer con seek al inicio
- ✅ Inserta el anuncio de forma síncrona
- ✅ Reanuda reproducción solo si no se insertó anuncio

#### 3. Protecciones Adicionales

- ✅ Verificación en `playFromCard()`: Cancela inserción si usuario quiere reproducir
- ✅ Verificación en `togglePlayPause()`: Cancela inserción si usuario hace play/pause
- ✅ Verificación en `AdInsertionManager`: Omite seek si usuario está reproduciendo nueva canción

## 📊 RESULTADO ESPERADO

- ✅ **Pausa Preventiva**: El reproductor se pausa 200ms antes del final, bloqueando el avance automático
- ✅ **Sin Inversión de Cola**: El anuncio se inserta ANTES de que el reproductor salte a la siguiente canción
- ✅ **Sin Interrupciones**: Si el usuario reproduce una nueva canción, el anuncio no interrumpe
- ✅ **Estado Limpio**: El estado del anuncio se limpia correctamente cuando el usuario reproduce una canción
- ✅ **Sin Condiciones de Carrera**: La pausa preventiva elimina las race conditions entre inserción y reproducción

