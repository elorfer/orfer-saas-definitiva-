# Reproductor Profesional de Audio

## Descripción

Este es un reproductor profesional de audio para Flutter que incluye todas las funcionalidades avanzadas requeridas:

- ✅ Reproducción en background con AudioService
- ✅ Controles del sistema (bloqueo de pantalla, notificaciones)
- ✅ Notificación persistente con controles
- ✅ Pausa automática en llamadas/notificaciones (AudioSession)
- ✅ Control de volumen
- ✅ Barra de progreso con seek draggable
- ✅ Tiempo transcurrido y total
- ✅ Botones anterior/siguiente
- ✅ Imagen del álbum/cover
- ✅ Título y artista
- ✅ Animaciones suaves

## Archivos Creados

1. **`professional_audio_controller.dart`** - Controlador principal que maneja la lógica del reproductor
2. **`professional_audio_handler.dart`** - Handler para AudioService (background)
3. **`professional_audio_service.dart`** - Servicio que integra controller y handler
4. **`professional_audio_provider.dart`** - Providers de Riverpod para el estado
5. **`professional_audio_player.dart`** - Widget del reproductor con UI moderna
6. **`audio_player_migration.dart`** - Utilidades para migrar gradualmente del reproductor básico

## Uso Básico

### 1. Inicializar el servicio (en main.dart o app inicial)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/professional_audio_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar el servicio profesional (opcional, se inicializa automáticamente)
  final audioService = ProfessionalAudioService();
  await audioService.initialize(enableBackground: true);
  
  runApp(const ProviderScope(child: MyApp()));
}
```

### 2. Usar el widget del reproductor

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/widgets/professional_audio_player.dart';

class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          // Tu contenido aquí
          
          // El reproductor profesional aparecerá automáticamente cuando haya una canción
          const ProfessionalAudioPlayer(),
        ],
      ),
    );
  }
}
```

### 3. Cargar una canción

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/professional_audio_service.dart';
import 'core/models/song_model.dart';

// Obtener el servicio
final audioService = ref.read(professionalAudioServiceProvider);

// Cargar una canción
await audioService.loadSong(song);

// O cargar una playlist
await audioService.loadPlaylist(songs, startIndex: 0);

// Reproducir
await audioService.play();

// Pausar
await audioService.pause();

// Buscar a una posición específica
await audioService.seek(Duration(seconds: 30));

// Establecer volumen (0.0 - 1.0)
await audioService.setVolume(0.7);

// Siguiente canción
await audioService.next();

// Canción anterior
await audioService.previous();
```

## Migración Gradual

Para migrar gradualmente del reproductor básico al profesional sin romper nada:

### Opción 1: Usar AudioPlayerWrapper

```dart
import 'core/widgets/audio_player_migration.dart';

// Usar el wrapper que detecta automáticamente
AudioPlayerWrapper(
  // Parámetros solo necesarios para el reproductor básico
  songTitle: song?.title,
  artistName: song?.artist?.displayName,
  imageUrl: song?.coverArtUrl,
  isPlaying: isPlaying,
  // ... otros parámetros
)

// O forzar un tipo específico
AudioPlayerWrapper(
  type: AudioPlayerType.professional, // o AudioPlayerType.basic
)
```

### Opción 2: Cambiar el tipo globalmente

```dart
import 'core/widgets/audio_player_migration.dart';

// Cambiar a reproductor profesional
changeAudioPlayerType(ref, AudioPlayerType.professional);

// Volver al básico si hay problemas
changeAudioPlayerType(ref, AudioPlayerType.basic);
```

## Configuración Adicional

### Android

Agregar permisos en `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

### iOS

Agregar en `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

## Características Implementadas

### AudioPlayerController

- ✅ Carga de canción desde URL
- ✅ `play()`, `pause()`, `stop()`
- ✅ `seek(Duration position)`
- ✅ Streams de posición, estado y duración
- ✅ Control de volumen
- ✅ Manejo de playlists

### ProfessionalAudioHandler (AudioService)

- ✅ Reproducción en background
- ✅ Notificación persistente
- ✅ Controles del sistema
- ✅ Sincronización con el controlador

### ProfessionalAudioPlayer (Widget)

- ✅ UI moderna con glassmorphism y neumorphism
- ✅ Barra de progreso draggable
- ✅ Control de volumen
- ✅ Botones con animaciones suaves
- ✅ Imagen del álbum con Hero animation
- ✅ Tiempo transcurrido y total

### AudioSession

- ✅ Pausa automática en llamadas
- ✅ Pausa automática en notificaciones
- ✅ Manejo de interrupciones
- ✅ Detección de desconexión de auriculares

## Notas Importantes

1. El reproductor profesional se inicializa automáticamente cuando se usa el provider.
2. El modo background requiere permisos especiales en Android e iOS.
3. La notificación persistente solo aparece cuando hay una canción reproduciéndose.
4. El reproductor básico sigue funcionando y no se rompe nada existente.

## Solución de Problemas

### La notificación no aparece
- Verifica que el modo background esté habilitado
- Revisa los permisos en AndroidManifest.xml
- En iOS, verifica UIBackgroundModes

### El audio se detiene en background
- Asegúrate de que AudioService esté inicializado
- Verifica que `enableBackground: true` esté configurado

### Los controles no funcionan
- Verifica que el handler esté sincronizado con el controller
- Revisa que los streams estén configurados correctamente

## Próximos Pasos

1. Integrar el reproductor en tu app principal
2. Reemplazar gradualmente las llamadas al reproductor básico
3. Probar en dispositivos físicos Android e iOS
4. Personalizar los estilos según tu tema







