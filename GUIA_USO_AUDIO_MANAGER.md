# 🎵 Guía de Uso: AudioManager Profesional

## ✅ Implementación Completada

Se ha implementado un sistema de audio profesional tipo Spotify con cambio atómico entre modos, protección contra estados cruzados y verificación de contexto para UI.

## 🎯 Características Principales

### 1. **Enum PlaybackMode**
```dart
enum PlaybackMode {
  algorithm,  // Reproducción inteligente con algoritmo
  fixedQueue, // Reproducción de playlist/artista completa
  none,       // Sin modo activo
}
```

### 2. **ContextId para Identificación de Contexto**
- Cada modo puede tener un `contextId` (playlistId, artistId, etc.)
- La UI solo muestra "playing" si el modo Y el contexto coinciden

### 3. **Mutex para Operaciones Atómicas**
- Protección contra cambios de modo simultáneos
- Garantiza que solo una operación ocurra a la vez

### 4. **Limpieza Estricta**
- `stop()` espera hasta que el player esté en estado `idle`
- Listeners se desconectan antes de cambiar de modo
- Colas se limpian completamente

## 📖 Uso desde UI

### Reproducir desde Tarjeta (Algoritmo)

```dart
// ✅ CORRECTO: Usar playFromCard() - siempre hace switchMode atómico
await ref.read(unifiedAudioProviderFixed.notifier).playFromCard(song);

// ❌ INCORRECTO: No usar playSong() directamente desde tarjeta
// await ref.read(unifiedAudioProviderFixed.notifier).playSong(song);
```

### Reproducir Playlist/Artista Completa (Fixed Queue)

```dart
// ✅ CORRECTO: Usar switchMode con contextId
await ref.read(unifiedAudioProviderFixed.notifier).switchMode(
  newMode: PlaybackMode.fixedQueue,
  fixedQueueSongs: songs,
  contextId: playlistId, // o artistId - IMPORTANTE para UI
);

// O usar onPressPlayAll() que internamente usa switchMode
await ref.read(unifiedAudioProviderFixed.notifier).onPressPlayAll(songs);
```

### Verificar si una Canción está Reproduciéndose (UI)

```dart
// ✅ CORRECTO: Verificar modo + contexto + songId
final isPlaying = ref.watch(isPlayingInContextProvider((
  songId: song.id,
  expectedMode: PlaybackMode.fixedQueue,
  expectedContextId: playlistId,
)));

// O usar el método directamente
final notifier = ref.read(unifiedAudioProviderFixed.notifier);
final isPlaying = notifier.isPlayingInContext(
  songId: song.id,
  expectedMode: PlaybackMode.fixedQueue,
  expectedContextId: playlistId,
);
```

### Ejemplo Completo: Widget de Playlist

```dart
class PlaylistSongCard extends ConsumerWidget {
  final Song song;
  final String playlistId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Verificar si esta canción está reproduciéndose en ESTA playlist
    final isPlaying = ref.watch(isPlayingInContextProvider((
      songId: song.id,
      expectedMode: PlaybackMode.fixedQueue,
      expectedContextId: playlistId,
    )));
    
    return ListTile(
      title: Text(song.title),
      trailing: IconButton(
        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        onPressed: () async {
          if (isPlaying) {
            // Pausar
            await ref.read(unifiedAudioProviderFixed.notifier).pause();
          } else {
            // Reproducir playlist completa desde esta canción
            final allSongs = [...]; // Obtener todas las canciones de la playlist
            await ref.read(unifiedAudioProviderFixed.notifier).switchMode(
              newMode: PlaybackMode.fixedQueue,
              fixedQueueSongs: allSongs,
              contextId: playlistId, // ✅ CRÍTICO: Pasar playlistId
            );
          }
        },
      ),
    );
  }
}
```

### Ejemplo Completo: Widget de Tarjeta Normal

```dart
class SongCard extends ConsumerWidget {
  final Song song;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Verificar si esta canción está reproduciéndose en modo algoritmo
    final isPlaying = ref.watch(isPlayingInContextProvider((
      songId: song.id,
      expectedMode: PlaybackMode.algorithm,
      expectedContextId: null, // Algoritmo no tiene contexto específico
    )));
    
    return Card(
      child: ListTile(
        title: Text(song.title),
        trailing: IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () async {
            if (isPlaying) {
              // Pausar
              await ref.read(unifiedAudioProviderFixed.notifier).pause();
            } else {
              // ✅ CORRECTO: Usar playFromCard() para cambio atómico
              await ref.read(unifiedAudioProviderFixed.notifier).playFromCard(song);
            }
          },
        ),
      ),
    );
  }
}
```

## 🛡️ Protecciones Implementadas

### 1. **Mutex**
- Solo una operación de cambio de modo puede ocurrir a la vez
- Si hay una operación en curso, las siguientes esperan

### 2. **Limpieza Estricta**
- `stop()` espera hasta que el player esté en estado `idle`
- Listeners se desconectan antes de cambiar de modo
- Colas se limpian completamente

### 3. **Verificación de Contexto**
- UI solo muestra "playing" si:
  - `playbackMode` coincide
  - `contextId` coincide
  - `currentSongId` coincide
  - `isPlaying == true`

### 4. **Preload Antes de Reproducir**
- Primera canción se precarga antes de reproducir
- Espera 200ms para que el preload se inicie

## 🔍 Debugging

### Logs Importantes

- `[SWITCH_MODE]`: Cambios de modo
- `[PLAY_FROM_CARD]`: Reproducción desde tarjeta
- `[WAIT_STOP]`: Espera de stop()
- `[ALGORITMO_LISTENER]`: Listener de algoritmo
- `[FIXED_QUEUE_LISTENER]`: Listener de fixed queue

### Verificar Estado Actual

```dart
final state = ref.watch(unifiedAudioProviderFixed);
print('Modo: ${state.playbackMode}');
print('Contexto: ${state.contextId}');
print('Canción: ${state.currentSong?.title}');
print('Reproduciendo: ${state.isPlaying}');
```

## ⚠️ Errores Comunes a Evitar

### ❌ Error 1: Usar playSong() directamente desde tarjeta
```dart
// ❌ INCORRECTO
await ref.read(unifiedAudioProviderFixed.notifier).playSong(song);

// ✅ CORRECTO
await ref.read(unifiedAudioProviderFixed.notifier).playFromCard(song);
```

### ❌ Error 2: No pasar contextId en fixed queue
```dart
// ❌ INCORRECTO - UI no podrá verificar correctamente
await ref.read(unifiedAudioProviderFixed.notifier).switchMode(
  newMode: PlaybackMode.fixedQueue,
  fixedQueueSongs: songs,
  // contextId: null - ❌ Falta contextId
);

// ✅ CORRECTO
await ref.read(unifiedAudioProviderFixed.notifier).switchMode(
  newMode: PlaybackMode.fixedQueue,
  fixedQueueSongs: songs,
  contextId: playlistId, // ✅ Pasar contextId
);
```

### ❌ Error 3: Verificar solo currentSongId sin contexto
```dart
// ❌ INCORRECTO - Puede mostrar "playing" en contexto equivocado
final isPlaying = state.currentSong?.id == song.id && state.isPlaying;

// ✅ CORRECTO - Verifica modo + contexto + songId
final isPlaying = ref.watch(isPlayingInContextProvider((
  songId: song.id,
  expectedMode: PlaybackMode.fixedQueue,
  expectedContextId: playlistId,
)));
```

## 🧪 Pruebas Manuales

### Escenario 1: Playlist → Tarjeta
1. Reproducir playlist (playAll)
2. Verificar que playlist UI muestra "playing"
3. Tocar una tarjeta de canción diferente
4. Verificar que:
   - Playlist deja de mostrar "playing"
   - Tarjeta muestra "playing"
   - Audio cambia correctamente

### Escenario 2: Taps Rápidos
1. Tocar playAll
2. Inmediatamente tocar tarjeta
3. Inmediatamente tocar playAll
4. Verificar que:
   - No se bloquea
   - Siempre termina en el último modo solicitado
   - No hay estados fantasma

### Escenario 3: Cambio de Playlist
1. Reproducir playlist A
2. Reproducir playlist B
3. Verificar que:
   - Playlist A deja de mostrar "playing"
   - Playlist B muestra "playing"
   - Audio cambia correctamente

## 📝 Resumen de Métodos Públicos

### Métodos Principales

- `playFromCard(Song song)`: Reproducir desde tarjeta (siempre usa switchMode)
- `switchMode(...)`: Cambio atómico entre modos
- `onPressPlayAll(List<Song> songs)`: Manejar botón "Reproducir Todo"
- `isPlayingInContext(...)`: Verificar si canción está reproduciéndose en contexto

### Providers para UI

- `unifiedAudioProviderFixed`: Estado completo
- `playbackModeProviderFixed`: Modo actual
- `contextIdProviderFixed`: Contexto actual
- `isPlayingInContextProvider`: Helper para verificación de contexto

## ✅ Estado Final

El sistema está completamente implementado y listo para usar. Todos los problemas reportados deberían estar resueltos:

- ✅ Sin desincronizaciones
- ✅ Sin bloqueos
- ✅ Sin estados fantasma
- ✅ Sin errores de primera canción
- ✅ Sin mezclas de modos
- ✅ UI muestra estado correcto según contexto







