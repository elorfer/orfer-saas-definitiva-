import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../services/professional_audio_service.dart';
import '../services/professional_audio_controller.dart';
import '../models/song_model.dart';
import 'dart:async';

/// Provider del servicio profesional de audio
/// El servicio es un singleton, siempre devuelve la misma instancia
final professionalAudioServiceProvider =
    Provider<ProfessionalAudioService>((ref) {
  final service = ProfessionalAudioService();
  
  ref.onDispose(() {
    service.dispose().catchError((_) {});
  });
  
  return service;
});

/// Provider del controlador de audio
/// Devuelve el controller solo si el servicio está inicializado
final professionalAudioControllerProvider =
    Provider<AudioPlayerController?>((ref) {
  final service = ref.watch(professionalAudioServiceProvider);
  
  if (service.isInitialized && service.controller != null) {
    return service.controller!;
  }
  
  return null;
});

/// Provider del estado del reproductor
final professionalPlayerStateProvider =
    StreamProvider<PlayerState>((ref) {
  final controller = ref.watch(professionalAudioControllerProvider);
  
  if (controller == null) {
    return const Stream<PlayerState>.empty();
  }
  
  return controller.stateStream;
});

/// Provider de la posición actual de reproducción
final professionalPositionProvider = StreamProvider<Duration>((ref) {
  final controller = ref.watch(professionalAudioControllerProvider);
  
  if (controller == null) {
    return Stream<Duration>.value(Duration.zero);
  }
  
  return controller.positionStream;
});

/// Provider de la duración de la canción actual
final professionalDurationProvider = StreamProvider<Duration?>((ref) {
  final controller = ref.watch(professionalAudioControllerProvider);
  
  if (controller == null) {
    return Stream<Duration?>.value(null);
  }
  
  return controller.durationStream;
});

/// Provider de la canción actual
/// Emite el valor actual inmediatamente y luego escucha cambios
final professionalCurrentSongProvider = StreamProvider<Song?>((ref) async* {
  // Primero intentar obtener el controller
  final controller = ref.watch(professionalAudioControllerProvider);
  
  // Si el controller no está disponible, intentar obtenerlo directamente del servicio
  AudioPlayerController? activeController = controller;
  if (activeController == null) {
    final service = ref.read(professionalAudioServiceProvider);
    if (service.isInitialized && service.controller != null) {
      activeController = service.controller;
    }
  }
  
  if (activeController == null) {
    yield null;
    return;
  }
  
  // Emitir el valor actual inmediatamente si está disponible
  if (activeController.currentSong != null) {
    yield activeController.currentSong;
  } else {
    yield null;
  }
  
  // Luego escuchar el stream para cambios futuros
  yield* activeController.currentSongStream.distinct();
});

/// Provider sincrónico de la canción actual (último valor)
final professionalCurrentSongSyncProvider = Provider<Song?>((ref) {
  final asyncValue = ref.watch(professionalCurrentSongProvider);
  return asyncValue.maybeWhen(
    data: (song) => song,
    orElse: () => null,
  );
});

/// Provider del estado de reproducción (playing/paused)
final professionalIsPlayingProvider = Provider<bool>((ref) {
  final playerState = ref.watch(professionalPlayerStateProvider);
  return playerState.maybeWhen(
    data: (state) => state.playing,
    orElse: () => false,
  );
});

/// Provider del volumen actual
final professionalVolumeProvider = Provider<double>((ref) {
  final controller = ref.watch(professionalAudioControllerProvider);
  return controller?.volume ?? 1.0;
});

