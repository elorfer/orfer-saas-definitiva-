# 📋 Lista de Tareas: Implementación de Controles del Reproductor

## Estado Actual
- ✅ **Play/Pause**: Funcional
- ⚠️ **Previous**: Implementado pero placeholder (no funciona completamente)
- ⚠️ **Next**: Implementado pero placeholder (no funciona completamente)
- ❌ **Shuffle**: No implementado (botón vacío)
- ❌ **Repeat**: No implementado (botón vacío)

---

## 📝 Tareas Detalladas

### 1. **Agregar Campos de Estado para Shuffle y Repeat**
**Archivo**: `apps/frontend/lib/core/providers/unified_audio_provider_fixed.dart`

**Cambios necesarios**:
- Agregar enum `RepeatMode` con valores: `off`, `all`, `one`
- Agregar campo `isShuffled: bool` en `UnifiedAudioState`
- Agregar campo `repeatMode: RepeatMode` en `UnifiedAudioState`
- Actualizar constructor y `copyWith()` para incluir estos campos
- Actualizar `operator ==` y `hashCode` para incluir estos campos

**Código ejemplo**:
```dart
enum RepeatMode { off, all, one }

class UnifiedAudioState {
  final bool isShuffled;
  final RepeatMode repeatMode;
  // ... otros campos
}
```

---

### 2. **Implementar Método toggleShuffle()**
**Archivo**: `apps/frontend/lib/core/providers/unified_audio_provider_fixed.dart`

**Funcionalidad**:
- Alternar estado `isShuffled` entre `true` y `false`
- Si se activa shuffle, mezclar la cola de reproducción actual
- Si se desactiva shuffle, restaurar orden original de la cola
- Actualizar estado con `setState()`

**Método**:
```dart
Future<void> toggleShuffle() async {
  state = state.copyWith(isShuffled: !state.isShuffled);
  // Si se activa shuffle, mezclar cola actual
  // Si se desactiva, restaurar orden original
}
```

---

### 3. **Implementar Método toggleRepeat()**
**Archivo**: `apps/frontend/lib/core/providers/unified_audio_provider_fixed.dart`

**Funcionalidad**:
- Ciclar entre modos: `off` → `all` → `one` → `off`
- Actualizar estado con `setState()`
- El modo `one` repite la canción actual infinitamente
- El modo `all` repite toda la cola/playlist

**Método**:
```dart
Future<void> toggleRepeat() async {
  RepeatMode nextMode;
  switch (state.repeatMode) {
    case RepeatMode.off:
      nextMode = RepeatMode.all;
      break;
    case RepeatMode.all:
      nextMode = RepeatMode.one;
      break;
    case RepeatMode.one:
      nextMode = RepeatMode.off;
      break;
  }
  state = state.copyWith(repeatMode: nextMode);
}
```

---

### 4. **Implementar Método next() Completo**
**Archivo**: `apps/frontend/lib/core/providers/unified_audio_provider_fixed.dart`

**Funcionalidad**:
- Si `repeatMode == RepeatMode.one`: reiniciar canción actual
- Si hay cola de reproducción:
  - Si `isShuffled == true`: reproducir siguiente canción aleatoria de la cola
  - Si `isShuffled == false`: reproducir siguiente canción en orden
- Si no hay cola: usar algoritmo de recomendación actual
- Actualizar historial de canciones recientes

**Lógica**:
```dart
Future<void> next() async {
  if (state.repeatMode == RepeatMode.one) {
    // Reiniciar canción actual
    await _audioPlayer.seek(Duration.zero);
    return;
  }
  
  if (_playlistQueue.isNotEmpty) {
    Song? nextSong;
    if (state.isShuffled) {
      nextSong = _playlistQueue[_getRandomIndex()];
    } else {
      nextSong = _playlistQueue[_currentIndex + 1];
    }
    if (nextSong != null) {
      await playSong(nextSong);
    }
  } else {
    // Usar algoritmo de recomendación actual
    await _handleSongCompletion();
  }
}
```

---

### 5. **Implementar Método previous() Completo**
**Archivo**: `apps/frontend/lib/core/providers/unified_audio_provider_fixed.dart`

**Funcionalidad**:
- Si posición actual > 3 segundos: reiniciar canción actual
- Si posición actual < 3 segundos:
  - Si hay cola de reproducción:
    - Si `isShuffled == true`: reproducir canción anterior aleatoria de la cola
    - Si `isShuffled == false`: reproducir canción anterior en orden
  - Si no hay cola: usar historial de canciones recientes

**Lógica**:
```dart
Future<void> previous() async {
  final position = state.currentPosition;
  
  // Si está más de 3 segundos, reiniciar canción
  if (position.inSeconds > 3) {
    await _audioPlayer.seek(Duration.zero);
    return;
  }
  
  // Si hay cola, ir a canción anterior
  if (_playlistQueue.isNotEmpty && _currentIndex > 0) {
    Song? prevSong;
    if (state.isShuffled) {
      prevSong = _playlistQueue[_getPreviousRandomIndex()];
    } else {
      prevSong = _playlistQueue[_currentIndex - 1];
    }
    if (prevSong != null) {
      await playSong(prevSong);
    }
  } else if (_recentSongIds.isNotEmpty) {
    // Usar historial de canciones recientes
    final lastSongId = _recentSongIds.last;
    // Buscar y reproducir última canción del historial
  }
}
```

---

### 6. **Crear Sistema de Playlist/Cola de Reproducción**
**Archivo**: `apps/frontend/lib/core/providers/unified_audio_provider_fixed.dart`

**Funcionalidad**:
- Crear lista `_playlistQueue: List<Song>` para almacenar cola de reproducción
- Crear variable `_currentIndex: int` para índice actual en la cola
- Crear lista `_originalQueueOrder: List<Song>` para guardar orden original (cuando shuffle está activo)
- Métodos necesarios:
  - `setPlaylist(List<Song> songs, int startIndex)` - Establecer nueva cola
  - `addToQueue(Song song)` - Agregar canción al final de la cola
  - `removeFromQueue(int index)` - Remover canción de la cola
  - `clearQueue()` - Limpiar cola
  - `shuffleQueue()` - Mezclar cola
  - `restoreQueueOrder()` - Restaurar orden original

**Estructura**:
```dart
class UnifiedAudioNotifier {
  List<Song> _playlistQueue = [];
  List<Song> _originalQueueOrder = [];
  int _currentIndex = -1;
  
  void setPlaylist(List<Song> songs, int startIndex) {
    _playlistQueue = List.from(songs);
    _originalQueueOrder = List.from(songs);
    _currentIndex = startIndex;
  }
  
  void shuffleQueue() {
    if (_playlistQueue.isEmpty) return;
    final currentSong = _playlistQueue[_currentIndex];
    _playlistQueue.shuffle();
    // Mantener canción actual al principio o en su posición
    _currentIndex = _playlistQueue.indexOf(currentSong);
  }
}
```

---

### 7. **Actualizar _handleSongCompletion() para Respetar Repeat Mode**
**Archivo**: `apps/frontend/lib/core/providers/unified_audio_provider_fixed.dart`

**Funcionalidad**:
- Si `repeatMode == RepeatMode.one`: reiniciar canción actual
- Si `repeatMode == RepeatMode.all`:
  - Si hay cola y es última canción: volver al inicio de la cola
  - Si no hay cola: usar algoritmo de recomendación
- Si `repeatMode == RepeatMode.off`:
  - Si hay cola: reproducir siguiente canción
  - Si no hay cola: usar algoritmo de recomendación actual

**Lógica**:
```dart
void _handleSongCompletion() {
  if (state.repeatMode == RepeatMode.one) {
    // Reiniciar canción actual
    _audioPlayer.seek(Duration.zero);
    _audioPlayer.play();
    return;
  }
  
  if (state.repeatMode == RepeatMode.all) {
    if (_playlistQueue.isNotEmpty && _currentIndex == _playlistQueue.length - 1) {
      // Volver al inicio de la cola
      _currentIndex = 0;
      playSong(_playlistQueue[0]);
      return;
    }
  }
  
  // Continuar con lógica normal de next()
  _triggerNextSongRecommendation();
}
```

---

### 8. **Actualizar UI del Botón Shuffle**
**Archivo**: `apps/frontend/lib/core/widgets/professional_audio_player.dart`

**Funcionalidad**:
- Mostrar icono con color diferente cuando está activo
- Conectar con `toggleShuffle()` del provider
- Observar estado `isShuffled` para actualizar UI

**Código**:
```dart
Consumer(
  builder: (context, ref, child) {
    final isShuffled = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.isShuffled),
    );
    return IconButton(
      icon: Icon(
        Icons.shuffle_rounded,
        color: isShuffled ? NeumorphismTheme.coffeeMedium : Colors.white,
        size: 24,
      ),
      onPressed: () {
        ref.read(unifiedAudioProviderFixed.notifier).toggleShuffle();
      },
    );
  },
),
```

---

### 9. **Actualizar UI del Botón Repeat**
**Archivo**: `apps/frontend/lib/core/widgets/professional_audio_player.dart`

**Funcionalidad**:
- Mostrar iconos diferentes según el modo:
  - `off`: `Icons.repeat_rounded` (gris/blanco)
  - `all`: `Icons.repeat_rounded` (color destacado)
  - `one`: `Icons.repeat_one_rounded` (color destacado)
- Conectar con `toggleRepeat()` del provider
- Observar estado `repeatMode` para actualizar UI

**Código**:
```dart
Consumer(
  builder: (context, ref, child) {
    final repeatMode = ref.watch(
      unifiedAudioProviderFixed.select((state) => state.repeatMode),
    );
    
    IconData icon;
    Color color;
    
    switch (repeatMode) {
      case RepeatMode.off:
        icon = Icons.repeat_rounded;
        color = Colors.white.withValues(alpha: 0.7);
        break;
      case RepeatMode.all:
        icon = Icons.repeat_rounded;
        color = NeumorphismTheme.coffeeMedium;
        break;
      case RepeatMode.one:
        icon = Icons.repeat_one_rounded;
        color = NeumorphismTheme.coffeeMedium;
        break;
    }
    
    return IconButton(
      icon: Icon(icon, color: color, size: 24),
      onPressed: () {
        ref.read(unifiedAudioProviderFixed.notifier).toggleRepeat();
      },
    );
  },
),
```

---

### 10. **Conectar Botones en professional_audio_player.dart**
**Archivo**: `apps/frontend/lib/core/widgets/professional_audio_player.dart`

**Cambios necesarios**:
- Reemplazar `onPressed: () {}` del botón shuffle con `toggleShuffle()`
- Reemplazar `onPressed: () {}` del botón repeat con `toggleRepeat()`
- Verificar que `next()` y `previous()` estén conectados correctamente
- Agregar `Consumer` widgets para observar estados y actualizar UI

---

## 📊 Prioridad de Implementación

1. **Alta Prioridad**:
   - Tarea 1: Agregar campos de estado
   - Tarea 2: Implementar toggleShuffle()
   - Tarea 3: Implementar toggleRepeat()
   - Tarea 10: Conectar botones en UI

2. **Media Prioridad**:
   - Tarea 6: Sistema de playlist/cola
   - Tarea 4: Implementar next() completo
   - Tarea 5: Implementar previous() completo

3. **Baja Prioridad**:
   - Tarea 7: Actualizar _handleSongCompletion()
   - Tarea 8: UI del botón shuffle
   - Tarea 9: UI del botón repeat

---

## 🔗 Archivos a Modificar

1. `apps/frontend/lib/core/providers/unified_audio_provider_fixed.dart`
   - Agregar campos de estado
   - Implementar métodos de control
   - Crear sistema de playlist

2. `apps/frontend/lib/core/widgets/professional_audio_player.dart`
   - Conectar botones con provider
   - Actualizar UI para mostrar estados

---

## ✅ Checklist de Implementación

- [ ] Enum RepeatMode creado
- [ ] Campos isShuffled y repeatMode agregados al estado
- [ ] Método toggleShuffle() implementado
- [ ] Método toggleRepeat() implementado
- [ ] Sistema de playlist/cola creado
- [ ] Método next() completo implementado
- [ ] Método previous() completo implementado
- [ ] _handleSongCompletion() actualizado para repeat mode
- [ ] UI del botón shuffle actualizada
- [ ] UI del botón repeat actualizada
- [ ] Botones conectados en professional_audio_player.dart
- [ ] Pruebas realizadas

---

## 📝 Notas Adicionales

- El sistema de playlist puede iniciarse simple (solo cola básica) y expandirse después
- Considerar persistir estado de shuffle/repeat en preferencias del usuario
- El historial de canciones recientes (`_recentSongIds`) ya existe y puede usarse para previous()
- El algoritmo de recomendación actual puede seguir funcionando cuando no hay cola









