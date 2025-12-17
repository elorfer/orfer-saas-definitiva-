import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/unified_audio_provider_fixed.dart';
import '../../../core/services/player_navigation_service.dart';
import '../../../core/theme/neumorphism_theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/url_normalizer.dart';
import '../models/audio_ad_model.dart';
import 'ads_skip_button.dart';
import 'ad_duration_counter.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Mini reproductor de anuncios
/// Se muestra cuando isPlayingAd es true
/// Maneja lógica condicional para anuncios saltables y no saltables
class AdsMiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;

  const AdsMiniPlayer({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(unifiedAudioProviderFixed);
    final ad = playbackState.currentAd;
    
    // Si no hay anuncio o no se está reproduciendo, no mostrar nada
    if (ad == null || !playbackState.isPlayingAd) {
      return const SizedBox.shrink();
    }

    // 🛑 CRÍTICO: El botón de Skip solo se renderiza si el modelo lo permite
    final bool showSkipControl = ad.isSkippable;

    return GestureDetector(
      onTap: onTap ?? () {
        // ✅ MEJOR PRÁCTICA: Usar servicio centralizado para navegación
        PlayerNavigationService.openFullPlayer(
          context: context,
          ref: ref,
        );
      },
      child: Container(
      constraints: const BoxConstraints(minHeight: 72, maxHeight: 80), // ✅ FIX: Permitir altura flexible
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // ✅ FIX: Reducir padding vertical de 8 a 6
      decoration: BoxDecoration(
        color: NeumorphismTheme.background,
        borderRadius: const BorderRadius.all(Radius.circular(32)),
        border: Border.all(
          color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ FIX: Mantener min para evitar overflow
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              // Carátula del anuncio
              _buildAdCover(ad),
              
              const SizedBox(width: 12),
              
              // Información del anuncio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // ✅ FIX: Usar min para evitar overflow
                  children: [
                    // Badge "ANUNCIO"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), // ✅ FIX: Reducir padding vertical
                      decoration: BoxDecoration(
                        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ANUNCIO',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: NeumorphismTheme.coffeeDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3), // ✅ FIX: Reducir espacio de 4 a 3
                    // Nombre del anunciante
                    Text(
                      ad.advertiserName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: NeumorphismTheme.textPrimary,
                        fontSize: 13, // ✅ FIX: Reducir tamaño de fuente ligeramente
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Lógica condicional para el botón de salto o contador
              if (showSkipControl)
                // Si es saltable, mostrar botón con countdown
                AdsSkipButton(ad: ad)
              else
                // Si no es saltable, solo mostrar la duración restante
                AdDurationCounter(ad: ad),
            ],
          ),
          
          const SizedBox(height: 6), // ✅ FIX: Reducir espacio de 8 a 6
          
          // Barra de progreso del anuncio
          _buildProgressBar(playbackState, ad),
        ],
      ),
      ),
    );
  }

  /// Construir carátula del anuncio
  Widget _buildAdCover(AudioAd ad) {
    if (ad.coverImageUrl != null && ad.coverImageUrl!.isNotEmpty) {
      // ✅ FIX: Normalizar URL de imagen para evitar problemas de duplicación
      final normalizedUrl = UrlNormalizer.normalizeImageUrl(ad.coverImageUrl);
      if (normalizedUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: normalizedUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) => _buildPlaceholder(),
          ),
        );
      }
    }
    return _buildPlaceholder();
  }

  /// Placeholder cuando no hay carátula
  Widget _buildPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.volume_up,
        color: NeumorphismTheme.coffeeDark,
        size: 24,
      ),
    );
  }

  /// Construir barra de progreso del anuncio
  Widget _buildProgressBar(dynamic playbackState, AudioAd ad) {
    final currentPosition = playbackState.currentPosition;
    // ✅ FIX: Usar duración del modelo AudioAd como fallback si totalDuration es cero
    // Esto asegura que la barra de progreso siempre tenga una duración válida
    final totalDuration = playbackState.totalDuration.inMilliseconds > 0 
        ? playbackState.totalDuration 
        : ad.duration;
    
    double progress = 0.0;
    if (totalDuration.inMilliseconds > 0) {
      progress = (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: NeumorphismTheme.coffeeMedium.withValues(alpha: 0.2),
        valueColor: AlwaysStoppedAnimation<Color>(NeumorphismTheme.coffeeDark),
        minHeight: 2,
      ),
    );
  }
}

