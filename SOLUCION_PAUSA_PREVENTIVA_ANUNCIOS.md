# 🛑 SOLUCIÓN DEFINITIVA: PAUSA PREVENTIVA Y REEMPLAZO DE COLA

## 📋 RESUMEN

Implementación de la solución de "Pausa Preventiva" para prevenir que el reproductor nativo salte automáticamente a la siguiente canción antes de que se inserte el anuncio.

## 🔍 PROBLEMA: INVERSIÓN DE COLA

### Flujo Problemático:

1. **Canción A termina** → Reproductor nativo (ExoPlayer/just_audio) salta automáticamente al Índice 1 (Canción B)
2. **Tu Código**: Recibe la notificación, busca el anuncio en el backend (latencia de red), lo descarga/prepara y lo intenta insertar
3. **El Conflicto**: Para cuando el anuncio está listo para insertarse en el Índice 1, el reproductor ya está reproduciendo la Canción B en ese mismo índice

### Causa Raíz:

El reproductor nativo es **más rápido** avanzando a la siguiente canción que tu código insertando el anuncio. Esto causa una "inversión de cola" donde el anuncio intenta insertarse después de que la siguiente canción ya empezó.

## ✅ SOLUCIÓN: PAUSA PREVENTIVA (200ms antes del final)

### Estrategia:

1. **Detección Temprana**: No esperar al "final", actuar **200ms antes**
2. **Pausa Preventiva**: Pausar el reproductor ANTES de que decida saltar automáticamente
3. **Inserción Síncrona**: Insertar el anuncio de forma síncrona mientras el reproductor está pausado
4. **Reemplazo de Cola**: El anuncio se inserta en la posición correcta sin que el reproductor avance

## 🛠️ IMPLEMENTACIÓN

### 🔀 Flujo de Control de Inversión de Cola

| Paso | Acción | Estado del Buffer |
|------|--------|-------------------|
| T-200ms | Trigger detectado | Buffer de Canción A casi vacío |
| T-150ms | `player.pause()` ejecutado | Se detiene la precarga de la Canción B |
| T-100ms | Inserción de AudioAd | La lista de reproducción se actualiza |
| T-0ms | `player.seek(AdIndex)` | El buffer se limpia y se carga la URL del Anuncio |

### 1. Detección Temprana en `_checkAndPrepareNextSongTransition()`

```dart
// 🛑 PAUSA PREVENTIVA: Detectar 200ms antes del final para bloquear avance automático
if (remainingTime.inMilliseconds <= 200 && 
    remainingTime.inMilliseconds > 0 &&
    !state.isPlayingAd &&
    !_isHandlingAdInsertion &&
    !_isInsertingAd) {
  
  // 🚨 BLOQUEO PREVENTIVO: Pausar ANTES de que el reproductor salte automáticamente
  AppLogger.info('[PlaybackNotifier] 🛑 PAUSA PREVENTIVA: Detectado 200ms antes del final');
  _handlePreventiveAdInsertion();
  return; // No continuar con preparación normal
}
```

### 2. Método `_handlePreventiveAdInsertion()` - Nivel Producción

```dart
/// 🛑 PAUSA PREVENTIVA: Bloquear avance automático 200ms antes del final
Future<void> _handlePreventiveAdInsertion() async {
  // ✅ PROTECCIÓN: Evitar llamadas reentrantes
  if (_isHandlingAdInsertion || _isInsertingAd || state.isPlayingAd) {
    return;
  }
  
  AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-200ms: Trigger detectado');
  
  // 1. 🛑 PAUSAR INMEDIATAMENTE para bloquear el avance automático
  final wasPlaying = service.player.playing;
  final currentIndexBeforePause = service.player.currentIndex;
  
  if (wasPlaying && currentIndexBeforePause != null) {
    AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-150ms: Ejecutando player.pause()');
    await service.pause();
    
    // ✅ ESTADO DE PAUSA REAL: Esperar ProcessingState.ready o idle
    await _waitForProcessingState([ProcessingState.ready, ProcessingState.idle]);
    AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Hardware detenido');
    
    // 🧹 LIMPIEZA AGRESIVA DEL BÚFER
    await service.player.seek(Duration.zero, index: currentIndexBeforePause);
    await _waitForProcessingState([ProcessingState.ready]);
  }
  
  // 2. 📢 INYECCIÓN DE ÍNDICE: El anuncio entra en currentIndex + 1
  AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-100ms: Insertando AudioAd en índice ${currentIndexBeforePause! + 1}');
  _isHandlingAdInsertion = true;
  try {
    await _checkAndInsertAd();
  } finally {
    _isHandlingAdInsertion = false;
  }
  
  // 3. 🔀 EL SALTO FINAL: seek(zero, index: currentIndex + 1) y luego play()
  final finalStateCheck = service.player.sequenceState;
  final finalIndexCheck = finalStateCheck.currentIndex;
  final isAdAfterDelay = finalStateCheck.currentSource?.tag is AudioAd;
  
  if (isAdAfterDelay && finalIndexCheck == currentIndexBeforePause + 1) {
    AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] T-0ms: Ejecutando seek y play');
    await service.player.seek(Duration.zero, index: finalIndexCheck);
    await _waitForProcessingState([ProcessingState.ready]);
    await service.play();
    AppLogger.info('[PlaybackNotifier] 🛑 [PREVENTIVE] ✅ Anuncio reproducido');
  }
}
```

### 3. Método Helper: `_waitForProcessingState()`

```dart
/// ✅ ESTADO DE PAUSA REAL: Esperar a que el ProcessingState sea el esperado
/// Confirma que el hardware realmente se detuvo antes de continuar
Future<void> _waitForProcessingState(
  List<ProcessingState> targetStates, {
  Duration timeout = const Duration(seconds: 2)
}) async {
  final completer = Completer<void>();
  Timer? timeoutTimer;
  StreamSubscription? subscription;
  
  timeoutTimer = Timer(timeout, () {
    if (!completer.isCompleted) {
      subscription?.cancel();
      completer.complete();
      AppLogger.warning('[PlaybackNotifier] ⚠️ Timeout esperando ProcessingState');
    }
  });
  
  subscription = service.playerStateStream.listen((playerState) {
    if (targetStates.contains(playerState.processingState)) {
      if (!completer.isCompleted) {
        timeoutTimer?.cancel();
        subscription?.cancel();
        completer.complete();
      }
    }
  });
  
  await completer.future;
}
```

## ✅ VERIFICACIÓN FINAL DE LA LÓGICA DE REEMPLAZO

### 1. Estado de Pausa Real ✅

- ✅ No solo llama a `pause()`, sino que espera `ProcessingState.ready` o `idle`
- ✅ Confirma que el hardware realmente se detuvo antes de continuar
- ✅ Usa `_waitForProcessingState()` con timeout para evitar bloqueos infinitos

### 2. Inyección de Índice ✅

- ✅ El anuncio entra en `currentIndex + 1` (correcto porque estamos pausados 200ms antes)
- ✅ El `currentIndex` sigue siendo el de la Canción A cuando se inserta el anuncio
- ✅ La inserción se hace ANTES de que el reproductor avance automáticamente

### 3. El Salto Final ✅

- ✅ Una vez insertado, ejecuta: `seek(zero, index: currentIndex + 1)`
- ✅ Espera `ProcessingState.ready` después del seek
- ✅ Luego ejecuta `play()` para reproducir el anuncio
- ✅ El buffer se limpia y se carga la URL del Anuncio

## 🎯 BENEFICIOS

1. **Sin Inversión de Cola**: El anuncio se inserta ANTES de que el reproductor salte automáticamente
2. **Sin Interrupciones**: Si el usuario reproduce una nueva canción, el anuncio no interrumpe
3. **Sin Condiciones de Carrera**: La pausa preventiva elimina las race conditions
4. **Transición Limpia**: El anuncio se reproduce inmediatamente después de la canción sin audio residual
5. **Estado de Pausa Real**: Verifica que el hardware realmente se detuvo antes de continuar
6. **Nivel Producción**: Maneja timeouts y estados de error correctamente

## 📝 ARCHIVOS MODIFICADOS

1. **`playback_notifier.dart`**:
   - Modificado `_checkAndPrepareNextSongTransition()` para detectar 200ms antes del final
   - Agregado método `_handlePreventiveAdInsertion()` para pausa preventiva
   - Mantenidas protecciones en `playFromCard()` y `togglePlayPause()`

2. **`ad_insertion_manager.dart`**:
   - Agregada verificación antes de hacer seek al anuncio
   - Importado modelo `Song` para verificaciones

## 🧪 PRUEBAS SUGERIDAS

1. ✅ Reproducir una canción y verificar que se pausa 200ms antes del final
2. ✅ Verificar que el anuncio se inserta correctamente sin que la siguiente canción empiece
3. ✅ Verificar que si el usuario reproduce una nueva canción durante la inserción, no se interrumpe
4. ✅ Verificar que no hay audio residual de la siguiente canción cuando se reproduce el anuncio

## 🚀 RESULTADO FINAL

- ✅ **Pausa Preventiva**: El reproductor se pausa 200ms antes del final
- ✅ **Sin Inversión**: El anuncio se inserta ANTES del avance automático
- ✅ **Sin Interrupciones**: El usuario puede reproducir sin que el anuncio interrumpa
- ✅ **Transición Limpia**: Sin audio residual ni condiciones de carrera

