import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_ad_model.dart';
import '../services/ads_service.dart';
import '../../../core/providers/auth_provider.dart';

/// Provider para el servicio de anuncios
final adsServiceProvider = Provider<AdsService>((ref) {
  return AdsService();
});

/// Estado de anuncios (simple, solo para tracking)
class AdsState {
  final AudioAd? currentAd;
  final bool isLoading;

  const AdsState({
    this.currentAd,
    this.isLoading = false,
  });

  AdsState copyWith({
    AudioAd? currentAd,
    bool? isLoading,
  }) {
    return AdsState(
      currentAd: currentAd ?? this.currentAd,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Provider para el estado de anuncios
final adsProvider = NotifierProvider<AdsNotifier, AdsState>(() {
  return AdsNotifier();
});

/// Notifier para manejar el estado de anuncios
class AdsNotifier extends Notifier<AdsState> {
  late final AdsService _service;

  @override
  AdsState build() {
    _service = ref.read(adsServiceProvider);
    return const AdsState();
  }

  /// Obtener siguiente anuncio
  /// 
  /// [genre]: Género de la canción actual (para targeting)
  /// [artist]: Artista de la canción actual (para targeting)
  /// [playlistId]: ID de playlist si aplica (para targeting)
  /// 
  /// Retorna el anuncio o null si no hay anuncios disponibles o el usuario es premium
  Future<AudioAd?> getNextAd({
    String? genre,
    String? artist,
    String? playlistId,
  }) async {
    // Obtener estado premium del usuario
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    final isPremium = user?.isPremium ?? false;

    state = state.copyWith(isLoading: true);

    try {
      final ad = await _service.getNextAd(
        genre: genre,
        artist: artist,
        playlistId: playlistId,
        isPremium: isPremium,
      );

      state = state.copyWith(
        currentAd: ad,
        isLoading: false,
      );

      return ad;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return null;
    }
  }

  /// Registrar reproducción de anuncio
  Future<void> logPlay(
    String adId, {
    required int durationSeconds,
    required bool wasCompleted,
    required bool wasSkipped,
    String? genre,
    String? artist,
    String? playlistId,
  }) async {
    await _service.logPlay(
      adId,
      durationSeconds: durationSeconds,
      wasCompleted: wasCompleted,
      wasSkipped: wasSkipped,
      genre: genre,
      artist: artist,
      playlistId: playlistId,
    );
  }

  /// Registrar click en anuncio
  Future<void> logClick(String adId) async {
    await _service.logClick(adId);
  }

  /// Limpiar anuncio actual
  void clearCurrentAd() {
    state = state.copyWith(currentAd: null);
  }

  /// Obtener frecuencia de anuncios
  Future<int> fetchAdFrequency() async {
    return await _service.getAdFrequency();
  }
}

