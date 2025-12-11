# vintage_music_app

Aplicación de streaming musical vintage para usuarios y artistas.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 📋 Deuda Técnica Gestionada

### ⚠️ just_audio - ConcatenatingAudioSource (Deprecado)

**Ubicación:** `lib/core/services/audio_service.dart`

**Estado:** Funcional y estable. Advertencias informativas del linter.

**Razón:**
- `just_audio 0.10.5` aún requiere `ConcatenatingAudioSource` para crear colas de reproducción
- La nueva API (`setAudioSources` plural) no está disponible en esta versión
- El código actual funciona correctamente y es estable

**Plan de Migración:**
1. Actualizar `just_audio` a versión que soporte `setAudioSources` (plural)
2. Migrar `loadNewQueue()` y `appendToQueue()` a la nueva API
3. Verificar que `sequenceState.sequence` se maneje correctamente

**Prioridad:** Baja (se abordará en próxima actualización mayor del paquete)

**Impacto:** Ninguno. Las advertencias son informativas y no afectan la funcionalidad.
