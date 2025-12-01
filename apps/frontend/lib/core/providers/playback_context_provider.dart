import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/playback_context_service.dart';
import '../models/playback_context.dart';

/// Provider para el servicio de contexto de reproducción
final playbackContextServiceProvider = Provider<PlaybackContextService>((ref) {
  return PlaybackContextService();
});

/// Provider para el contexto actual de reproducción
final currentPlaybackContextProvider = StreamProvider<PlaybackContext?>((ref) {
  final service = ref.watch(playbackContextServiceProvider);
  return service.contextStream;
});

/// Provider para verificar si puede avanzar automáticamente
final canAutoAdvanceProvider = Provider<bool>((ref) {
  final contextAsync = ref.watch(currentPlaybackContextProvider);
  return contextAsync.when(
    data: (context) => context?.canAutoAdvance ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider para obtener el tipo de contexto actual
final currentContextTypeProvider = Provider<PlaybackContextType?>((ref) {
  final contextAsync = ref.watch(currentPlaybackContextProvider);
  return contextAsync.when(
    data: (context) => context?.type,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider para obtener información del contexto actual
final contextInfoProvider = Provider<String?>((ref) {
  final contextAsync = ref.watch(currentPlaybackContextProvider);
  return contextAsync.when(
    data: (context) => context?.displayDescription,
    loading: () => null,
    error: (_, __) => null,
  );
});











