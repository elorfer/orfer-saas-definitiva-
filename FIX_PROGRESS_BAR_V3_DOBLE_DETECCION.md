# 🔧 Fix V3: Doble Detección + Freeze Extendido (1.2s)

## 🎯 Cambios de V2 → V3

### Problema que Persistía
Incluso con el bloqueo de 800ms, el usuario reportaba que la barra **todavía se movía** brevemente.

### Hipótesis
El stream del audio player estaba disparando rebuilds **ANTES** de que `isPlayingAd` cambiara de `true` a `false`. Esto significaba que había un "hueco" temporal donde:

1. `skipAd()` se ejecuta
2. `seek(Duration.zero)` se ejecuta
3. Stream empieza a reportar nueva posición
4. **Widget se rebuilded con la nueva posición** ← AQUÍ ESTÁ EL PROBLEMA
5. DESPUÉS `isPlayingAd` cambia a `false`
6. Recién ahí se activa el freeze (demasiado tarde)

### Solución V3: Doble Detección

Ahora detectamos la transición de DOS formas:

#### Detección 1: Por Estado de Anuncio (Original)
```dart
if (_wasPlayingAd == true && isPlayingAd == false) {
  // Transición Ad→Song detectada
  _lastAdTransition = DateTime.now();
  // ... freeze de 1200ms
}
```

#### Detección 2: Por Cambio Abrupto de Canción (NUEVO)
```dart
if (currentSongId != _currentSongId) {
  // Si había progreso significativo (>5%) y cambió la canción
  if (_maxProgress > 0.05 && !isPlayingAd) {
    AppLogger.info('Cambio abrupto detectado');
    _lastAdTransition = DateTime.now();
    // ... freeze de 1200ms
  }
}
```

### Lógica de Detección 2

**¿Por qué funciona?**
- Durante un anuncio, `_maxProgress` va aumentando
- Cuando saltas el anuncio manualmente, la canción cambia (`currentSongId != _currentSongId`)
- Si `_maxProgress > 0.05` Y `!isPlayingAd`, sabemos que:
  - Había contenido reproduciéndose (no estábamos en 0)
  - Ahora cambió la canción
  - No estamos en un anuncio actualmente
  - **Conclusión: Es un skip de anuncio**

### Período de Freeze: 1200ms

**¿Por qué 1200ms?**
- `skipAd()` tiene HARD FREEZE de 400ms
- Margen de seguridad: 800ms adicionales
- Total: 1.2 segundos de certeza absoluta

### Flujo Completo

```
Usuario salta anuncio
↓
--- Escenario A: isPlayingAd cambia primero ---
isPlayingAd: true → false
→ Detección 1 activada ✅
→ FREEZE por 1200ms
→ Barra estática en 0

--- Escenario B: currentSongId cambia primero ---
currentSongId: "song-123" → "song-456"
→ Detección 2 activada ✅
→ FREEZE por 1200ms
→ Barra estática en 0

--- En ambos casos ---
Durante 1200ms:
- build() retorna widget estático
- StreamBuilder NO se ejecuta
- NO hay updates de progreso
- Barra visible al usuario: ████░░░░░░ (0%)

Después de 1200ms:
- setState() forzado
- build() retorna StreamBuilder
- Barra funciona normalmente
```

## 📊 Código Final

```dart
class _MiniPlayerProgressBarState extends ConsumerState<_MiniPlayerProgressBar> {
  double _maxProgress = 0.0;
  String? _currentSongId;
  bool? _wasPlayingAd;
  DateTime? _lastAdTransition;
  
  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(realCurrentSongProvider);
    final currentSongId = currentSong?.id;
    final isPlayingAd = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isPlayingAd),
    );
    
    // DETECCIÓN 1: Transición Ad→Song
    if (_wasPlayingAd == true && isPlayingAd == false) {
      _lastAdTransition = DateTime.now();
      Future.delayed(Duration(milliseconds: 1200), () {
        if (mounted) setState(() {});
      });
    }
    _wasPlayingAd = isPlayingAd;
    
    // DETECCIÓN 2: Cambio abrupto de canción
    if (currentSongId != _currentSongId) {
      if (_maxProgress > 0.05 && !isPlayingAd) {
        _lastAdTransition = DateTime.now();
        Future.delayed(Duration(milliseconds: 1200), () {
          if (mounted) setState(() {});
        });
      }
      _currentSongId = currentSongId;
      _maxProgress = 0.0;
    }
    
    // FREEZE CHECK
    final isInTransitionPeriod = _lastAdTransition != null && 
        DateTime.now().difference(_lastAdTransition!) < Duration(milliseconds: 1200);
    
    // EARLY RETURN: Widget estático
    if (isInTransitionPeriod) {
      return SizedBox(
        height: 2,
        child: LinearProgressIndicator(value: 0.0, ...),
      );
    }
    
    // NORMAL: StreamBuilder
    return StreamBuilder<Duration>(
      stream: audioService.smoothPositionStream,
      builder: (context, snapshot) {
        // ... lógica normal
      },
    );
  }
}
```

## 🧪 Testing Esperado

1. Reproducir canción
2. Esperar anuncio (progreso > 5%)
3. Saltar anuncio
4. **Observar:**
   - ✅ Barra se congela instantáneamente en 0
   - ✅ NO hay movimiento hacia adelante (ni siquiera 1 pixel)
   - ✅ Permanece en 0 por ~1.2 segundos
   - ✅ Luego empieza a avanzar suavemente

## 📝 Debugging

Si **TODAVÍA** hay movimiento, revisar logs:
```
[MiniProgressBar] 🔄 Transición Ad→Song detectada
[MiniProgressBar] 🔄 Cambio abrupto de canción detectado
[MiniProgressBar] 🛡️ FREEZE ACTIVO (1200ms)
[MiniProgressBar] 🔓 Fin del freeze (1200ms)
```

Si NO aparece "Transición detectada" o "Cambio abrupto detectado", significa que:
- El cambio de estado no está llegando al widget
- O el widget no se está rebuildeando cuando debería

## ⚠️ Si Persiste el Bug

Posibles causas:
1. El mini player se está reconstruyendo completamente (nuevo instance)
2. El StreamBuilder se está suscribiendo antes del freeze
3. Hay otro componente actualizando la barra (unlikely)

Solución nuclear:
- Eliminar `TweenAnimationBuilder` completamente
- Usar solo `LinearProgressIndicator` directo
- Eliminar animaciones de transición
