# 🔧 Fix: Barra de Progreso del Mini Reproductor - Salto de Anuncios

## 📋 Problema Identificado

Cuando se saltaba un anuncio manualmente, la barra de progreso del mini reproductor mostraba un comportamiento errático:
1. ✅ La siguiente canción empezaba a reproducirse
2. ❌ La barra de progreso intentaba avanzar rápidamente
3. ❌ Luego regresaba bruscamente a 0

## 🔍 Causa Raíz

El problema ocurría debido a dos factores:

### 1. **Reseteo Explícito de Posición (Línea 4967 - playback_notifier.dart)**
```dart
Future.delayed(const Duration(milliseconds: 400), () {
  state = state.copyWith(
    currentPosition: Duration.zero,  // ❌ PROBLEMA
  );
  ...
});
```

El flujo era:
- `seek(Duration.zero)` en línea 4958 → establece posición a 0
- Stream reporta posición durante 400ms (puede ser > 0 debido a buffering)
- Barra intenta avanzar con esos valores
- Después de 400ms, se fuerza `currentPosition: Duration.zero`
- Barra retrocede bruscamente

### 2. **Falta de Detección de Transiciones Ad→Song**

El componente `_MiniPlayerProgressBar` no detectaba específicamente cuando se salía de un anuncio, por lo que respondía a todos los updates del stream sin discriminar si estaban en medio de una transición.

## ✅ Soluciones Implementadas

### Fix 1: Eliminar Reseteo Explícito de Posición

**Archivo:** `playback_notifier.dart` (líneas 4965-4973)

```dart
// 🔓 Descongelar después de un pequeño delay para que el stream se asiente
Future.delayed(const Duration(milliseconds: 400), () {
  // ✅ FIX: NO resetear currentPosition aquí - el seek(Duration.zero) ya lo hizo
  // Resetear aquí causaba el "tirón" en la barra de progreso porque el stream
  // ya había reportado posición > 0 durante los 400ms de delay
  
  _isFreezingUI = false;
  _service?.setFreezeMode(false);
  AppLogger.info('[PlaybackNotifier] 🌡️ Desactivando HARD FREEZE - transición completada');
  ...
});
```

**Razón:** El `seek(Duration.zero)` ya establece la posición correcta. El stream listener la actualizará naturalmente sin necesidad de forzarla.

### Fix 2: Detectar Transiciones de Anuncio en la Barra de Progreso

**Archivo:** `mini_player_components.dart` (clase `_MiniPlayerProgressBarState`)

#### 2.1 Variables de Estado Añadidas

```dart
bool? _wasPlayingAd;          // Detectar transiciones de anuncio
DateTime? _lastAdTransition;  // Timestamp de última transición
```

#### 2.2 Detección de Transición Ad→Song

```dart
// ✅ DETECTAR TRANSICIÓN DE ANUNCIO
final isPlayingAd = ref.watch(
  unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
);

// ✅ FIX CRÍTICO: Detectar transición de anuncio a canción
if (_wasPlayingAd == true && isPlayingAd == false) {
  AppLogger.info('[MiniProgressBar] 🔄 Transición Ad→Song detectada, reseteando progreso');
  _maxProgress = 0.0;
  _currentSongId = currentSongId;
  _lastAdTransition = DateTime.now(); // ✅ Marcar timestamp
}
_wasPlayingAd = isPlayingAd;
```

#### 2.3 Período de "Freeze" Temporal

```dart
// ✅ PROTECCIÓN TEMPORAL: Ignorar actualizaciones durante 500ms después de transición
final isInTransitionPeriod = _lastAdTransition != null && 
    DateTime.now().difference(_lastAdTransition!) < const Duration(milliseconds: 500);

// En el StreamBuilder:
// ✅ PROTECCIÓN: Durante período de transición, forzar progreso a 0
if (isInTransitionPeriod) {
  currentProgress = 0.0;
  _maxProgress = 0.0;
} else {
  // Lógica normal de anti-retroceso
  ...
}
```

**Razón:** Durante los primeros 500ms después de saltar un anuncio, ignoramos completamente los updates del stream y mantenemos la barra en 0. Esto previene cualquier "salto" visual.

## 🎯 Resultado Esperado

Después de estos cambios:

1. ✅ Usuario salta un anuncio manualmente
2. ✅ La transición Ad→Song se detecta inmediatamente
3. ✅ La barra de progreso se resetea a 0 instantáneamente
4. ✅ Durante 500ms, ignora updates del stream (período de estabilización)
5. ✅ Después de 500ms, vuelve a funcionar normalmente con anti-retroceso
6. ✅ **NO HAY "AVANCE RÁPIDO Y REGRESO"**

## 📊 Archivos Modificados

1. **`apps/frontend/lib/core/providers/playback_notifier.dart`**
   - Eliminado reseteo explícito de `currentPosition` después del delay
   - Complejidad: 8/10

2. **`apps/frontend/lib/core/widgets/mini_player_components.dart`**
   - Añadida detección de transiciones Ad→Song
   - Añadido período de "freeze" temporal de 500ms
   - Complejidad: 7/10

## 🧪 Testing Recomendado

1. Reproducir una canción
2. Esperar a que aparezca un anuncio
3. Saltar el anuncio manualmente cuando sea posible
4. Observar la barra de progreso del mini reproductor
5. ✅ Confirmar que NO hay avance seguido de regreso
6. ✅ Confirmar que la barra se queda en 0 y luego avanza suavemente

## 🔧 Notas Técnicas

- El período de 500ms en `isInTransitionPeriod` está calibrado para cubrir el tiempo del "HARD FREEZE" (400ms) más un margen de seguridad
- La detección usa `_wasPlayingAd` para capturar el cambio de estado `true → false`
- Se mantiene toda la lógica anti-retroceso existente intacta para el funcionamiento normal
